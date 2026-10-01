#!/usr/bin/env python3
"""Generates the wiki tables whose content is derivable from the repo, into
marked regions of the pages that carry them, and checks they are current.

Why this exists: `check_wiki.py` used to *detect* drift in these tables
(`hosts`, `table`'s Directory/Class(es) columns, `counts`' table half) and an
agent then fixed the row by hand -- the module-counts table alone had its
rows hand-edited in 24 commits in September 2026, every one a number the
tree already knew. Since 2026-10-01 the model is generate, then lint that the
generated output is current: `just wiki-gen` rewrites the regions,
`just wiki-gen --check` (and `check_wiki.py generated`, so `just wiki-lint`
and preflight) fails when one is stale.

A region is delimited in the markdown by two comment lines:

    <!-- generated:<name> -- <where its facts come from> -->
    ...table...
    <!-- /generated -->

Everything between them is rewritten, the start marker's note included, so
an edit inside a region is lost on the next run unless it is in a
hand-written column (below). To change a generated fact, change its source
(the note says which) and run `just wiki-gen`. The region name must be one
`REGIONS` registers; each registered region must appear on its home page,
and may appear on other pages too (a `-for-agents` sibling restating the
same table carries the same region rather than a hand copy).

Hand-written columns. Some tables mix derived columns with prose nobody can
derive (hosts.md's Role, categories/00-INDEX.md's Imported by). Those
columns are preserved per row, matched by the row's key: the generator
rewrites every derived cell and carries the hand cell over from the row
with the same key. A new row (a host just added to hosts.nix) gets an empty
hand cell, which `--check` reports as a finding until someone fills it in;
a row whose key disappears is dropped, and the write run prints the text it
dropped so nothing vanishes silently. Hand columns are still prose, so
whatever checked them before (check_wiki.py's Imported-by heuristic) still
does -- only the derived columns moved here.

Generated regions are a mechanical touch: rewriting one does not bump the
page's `_Last modified:_` (styleguide.md, "Required on every page"), which
also keeps a region update from tripping the `siblings` check.

Parsing is reused from check_wiki.py (hosts.nix, category shims, host import
lists, class declarations), never restated here.

    wiki_gen.py [--check] [repo-root]

Pure stdlib; fixture tests in test_wiki_gen.py (`just wiki-gen-test`, part
of `just preflight` and so of CI).
"""
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import check_wiki as cw  # noqa: E402

START = re.compile(r'(?m)^<!-- generated:([\w-]+)\b[^\n]*-->[ \t]*$')
END = '<!-- /generated -->'
REGION = re.compile(
    r'(?ms)^<!-- generated:(?P<name>[\w-]+)\b[^\n]*?-->[ \t]*\n'
    r'(?P<body>.*?)^<!-- /generated -->[ \t]*$')
END_LINE = re.compile(r'(?m)^<!-- /generated -->[ \t]*$')
CELL_SPLIT = re.compile(r'(?<!\\)\|')
FENCED = re.compile(r'(?ms)^(```|~~~).*?^\1[^\n]*$')


def _unfenced(text):
    """`text` with every fenced code block blanked to spaces, newlines and
    length kept -- so a marker shown as an example in a fence (styleguide.md
    has one) is not a region, and match offsets still index the original."""
    return FENCED.sub(lambda m: re.sub(r'[^\n]', ' ', m.group(0)), text)


class GenError(Exception):
    """A source the generator needs is missing or unreadable -- reported as
    a finding rather than rendering a table from half the facts."""


# --- table plumbing -------------------------------------------------------

def render_table(headers, rows):
    lines = ['| ' + ' | '.join(headers) + ' |', '|' + '---|' * len(headers)]
    lines += ['| ' + ' | '.join(r) + ' |' for r in rows]
    return '\n'.join(lines)


def parse_table(body):
    """[{header: cell}, ...] for the first markdown table in `body`; [] if
    there is none (a region being adopted for the first time, or emptied)."""
    lines = [l.strip() for l in body.splitlines() if l.strip().startswith('|')]
    if len(lines) < 2:
        return []
    split = lambda l: [c.strip() for c in CELL_SPLIT.split(l.strip('|'))]
    headers = split(lines[0])
    return [dict(zip(headers, split(l))) for l in lines[2:]]


def _same_key(row_id, cell):
    """Does an existing row's key cell belong to `row_id`? The cell itself,
    or the id as a whole word-ish token in it, so a re-rendered key cell (a
    link target that changed, say) still finds its old hand-written cells."""
    return cell == row_id or row_id in re.findall(r'[\w-]+', cell)


# --- the regions ----------------------------------------------------------

class Region:
    """One generated table. `rows(root)` yields (row_id, {header: cell})
    for the derived columns, in display order; `hand` names the columns
    carried over from the existing table."""

    def __init__(self, name, page, source, headers, key, hand, rows):
        self.name, self.page, self.source = name, pathlib.Path(page), source
        self.headers, self.key, self.hand, self.rows = headers, key, hand, rows

    def marker(self):
        note = (f'from {self.source}, by `just wiki-gen`; change the '
                f'source, not this table')
        if self.hand:
            note += '. Hand-written, kept per row: ' + ', '.join(self.hand)
        return f'<!-- generated:{self.name} -- {note} -->'

    def render(self, root, old_body):
        """(region text, empty hand cells, dropped old rows)."""
        old = parse_table(old_body)
        out, empty, used = [], [], set()
        for row_id, cells in self.rows(root):
            prev = next((i for i, r in enumerate(old)
                         if i not in used and _same_key(row_id, r.get(self.key, ''))),
                        None)
            if prev is not None:
                used.add(prev)
            for col in self.hand:
                cells[col] = old[prev].get(col, '') if prev is not None else ''
                if not cells[col]:
                    empty.append((row_id, col))
            out.append([cells[h] for h in self.headers])
        dropped = [r for i, r in enumerate(old) if i not in used]
        text = (self.marker() + '\n\n' + render_table(self.headers, out)
                + '\n\n' + END)
        return text, empty, dropped


def host_rows(root):
    """hosts.nix's `nire-*` entries in file order (forge-runner, a guest,
    has no `nire-` prefix and is excluded by HOST_LINE -- hosts.md says
    why). Wipes `/root`? is whether the host's effective import list holds
    `impermanence`; darwin has no initrd stage this repo touches, hence
    n/a. A NixOS host that does not wipe is bold: it is the exception
    AGENTS.md's Safety section warns about."""
    hosts = cw.actual_hosts(root)
    if not hosts:
        raise GenError('hosts.nix declares no nire-* hosts (or moved)')
    shorts = [h.removeprefix('nire-') for h in hosts]
    for s in shorts:
        p = root / 'flake' / 'modules' / 'host-config' / f'{s}-configuration.nix'
        if not p.exists():
            raise GenError(f'no {p.relative_to(root)} for nire-{s}')
    imports = cw.host_imports(root, cw.find_categories(root), shorts)
    for name, cls in hosts.items():
        short = name.removeprefix('nire-')
        if cls == 'darwin':
            wipes = 'n/a'
        elif 'impermanence' in imports[short]:
            wipes = 'yes'
        else:
            wipes = '**no**'
        yield name, {'Host': f'`{name}`', 'Class': cls,
                     'Wipes `/root`?': wipes,
                     'Tailnet name': f'`ts-{short}`'}


CLASS_ORDER = ['nixos', 'homeManager', 'darwin']
HOMELAB = 'general-config/homelab'
NESTED_NAMED_MAX = 3  # up to this many nested categories are named, past it counted


def category_rows(homelab):
    """Index table rows for every category with a wiki page: the homelab
    umbrella and its nested categories when `homelab`, everything else
    otherwise. Ordered by area then name (general-config before
    users-config). Directory notes nested categories; Class(es) is every
    `flake.modules.<class>` declared under the tree (check_wiki's
    category_classes, which says why nested trees count)."""
    def rows(root):
        modules = root / 'flake' / 'modules'
        pages = root / 'wiki' / 'categories'
        found = []
        for name, d in cw.find_categories(root).items():
            rel = d.relative_to(modules).as_posix()
            if (rel == HOMELAB or rel.startswith(HOMELAB + '/')) != homelab:
                continue
            if (pages / f'{name}.md').exists():
                link = f'{name}.md'
            elif (pages / name / '00-INDEX.md').exists():
                link = f'{name}/00-INDEX.md'
            else:
                continue  # no page, no row (amd, root-rollback)
            nested = sorted(p.parent.name for p in cw.shims_under(d) if p.parent != d)
            dir_cell = f'`{rel}/`'
            if 0 < len(nested) <= NESTED_NAMED_MAX:
                dir_cell += ' (+ nested ' + ', '.join(f'`{n}`' for n in nested) + ')'
            elif nested:
                dir_cell += f' (+ {len(nested)} nested)'
            classes = cw.category_classes(d)
            ordered = [c for c in CLASS_ORDER if c in classes] + sorted(classes - set(CLASS_ORDER))
            found.append(((rel.split('/')[0], name), name, {
                'Category': f'[{name}]({link})', 'Directory': dir_cell,
                'Class(es)': ', '.join(ordered)}))
        for _, name, cells in sorted(found, key=lambda t: t[0]):
            yield name, cells
    return rows


# The module-style-guide counts table: one row per convention the human
# style guide once stated as an inline count (moved to the sibling
# 2026-09-11, generated since 2026-10-01). The pattern is what the page's
# "recompute by hand" grep uses; None counts the files themselves.
COUNT_ROWS = [
    ('total `.nix` files under `flake/modules/`', None),
    ('module header (`moduleName = lib.removeSuffix ...`)',
     'moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);'),
    ('`# # description` as first body line', re.compile(r'(?m)^\s*# # description')),
    ('`with pkgs;` package lists', 'with pkgs;'),
]


def count_rows(root):
    files = sorted((root / 'flake' / 'modules').rglob('*.nix'))
    if not files:
        raise GenError('no .nix files under flake/modules/')
    texts = [f.read_text() for f in files]
    for label, pat in COUNT_ROWS:
        if pat is None:
            n = len(files)
        elif isinstance(pat, re.Pattern):
            n = sum(1 for t in texts if pat.search(t))
        else:
            n = sum(1 for t in texts if pat in t)
        yield label, {'What': label, 'Files': str(n)}


REGIONS = {r.name: r for r in [
    Region('hosts-table', 'wiki/hosts.md',
           "flake/modules/host-config/hosts.nix and each host's import list",
           ['Host', 'Class', 'Role', 'Wipes `/root`?', 'Tailnet name'],
           'Host', ['Role'], host_rows),
    Region('categories-index-system', 'wiki/categories/00-INDEX.md',
           'the dirsAsCategory.nix tree under flake/modules/ and the pages in wiki/categories/',
           ['Category', 'Directory', 'Class(es)', 'Imported by'],
           'Category', ['Imported by'], category_rows(homelab=False)),
    Region('categories-index-homelab', 'wiki/categories/00-INDEX.md',
           'the dirsAsCategory.nix tree under flake/modules/general-config/homelab/ and the pages in wiki/categories/',
           ['Category', 'Directory', 'Class(es)', 'Imported by'],
           'Category', ['Imported by'], category_rows(homelab=True)),
    Region('module-counts', 'wiki/module-style-guide-for-agents.md',
           'a count of the .nix files under flake/modules/',
           ['What', 'Files'], 'What', [], count_rows),
]}


# --- driving it -----------------------------------------------------------

def run(root, write):
    """Walks every wiki page's regions. Returns (findings, notes): findings
    are what --check fails on; notes are what a write run reports (dropped
    rows' hand text). With `write`, stale regions are rewritten in place."""
    findings, notes, seen = [], [], {}
    for page in cw.wiki_md(root):
        text = page.read_text()
        rel = page.relative_to(root)
        scan = _unfenced(text)
        starts = START.findall(scan)
        ends = len(END_LINE.findall(scan))
        regions = list(REGION.finditer(scan))
        if len(starts) != len(regions) or ends != len(regions):
            findings.append(
                f"BROKEN REGION  {rel}: {len(starts)} generated start marker(s), "
                f"{ends} end marker(s), {len(regions)} well-formed "
                f"region(s) -- every `<!-- generated:<name> ... -->` line needs "
                f"its own `{END}`")
        new_text, pos = [], 0
        for m in regions:
            name = m.group('name')
            seen.setdefault(name, []).append(rel)
            region = REGIONS.get(name)
            if region is None:
                findings.append(
                    f"UNKNOWN REGION  {rel}: 'generated:{name}' is not in "
                    f"wiki_gen.py's REGIONS ({', '.join(sorted(REGIONS))})")
                continue
            try:
                fresh, empty, dropped = region.render(
                    root, text[m.start('body'):m.end('body')])
            except GenError as e:
                findings.append(f"GEN ERROR  {rel}: region '{name}': {e}")
                continue
            for row_id, col in empty:
                findings.append(
                    f"EMPTY HAND CELL  {rel}: region '{name}' row '{row_id}' "
                    f"has no {col} -- it is hand-written; fill it in (the "
                    f"generated columns come from {region.source})")
            if fresh != text[m.start():m.end()]:
                if write:
                    for r in dropped:
                        if not any(r.get(c) for c in region.hand):
                            continue  # nothing hand-written was lost
                        notes.append(
                            f"dropped  {rel}: region '{name}' row "
                            f"{r.get(region.key, '?')!r} (no longer in "
                            f"{region.source}); its hand cells were "
                            f"{ {c: r.get(c, '') for c in region.hand} }")
                    new_text.append(text[pos:m.start()] + fresh)
                    pos = m.end()
                else:
                    findings.append(
                        f"STALE GENERATED  {rel}: region '{name}' does not match "
                        f"{region.source} -- run `just wiki-gen` (edit the source, "
                        f"not the region)")
        if write and new_text:
            page.write_text(''.join(new_text) + text[pos:])
            notes.append(f"updated  {rel}")
    for name, region in REGIONS.items():
        where = seen.get(name, [])
        if region.page not in where:
            findings.append(
                f"MISSING REGION  {region.page}: no 'generated:{name}' region "
                f"-- its table is gone, moved, or lost its markers, so nothing "
                f"keeps it current")
        if len(where) != len(set(where)):
            findings.append(
                f"DUPLICATE REGION  'generated:{name}' appears more than once "
                f"on one page: {sorted(set(p for p in where if where.count(p) > 1))}")
    return findings, notes


def check(root):
    """For check_wiki.py's `generated` subcommand."""
    return run(root, write=False)[0]


def main(argv):
    args = argv[1:]
    write = '--check' not in args
    args = [a for a in args if a != '--check']
    root = (pathlib.Path(args[0]).resolve() if args
            else pathlib.Path(__file__).resolve().parents[2])
    findings, notes = run(root, write)
    for n in notes:
        print(n)
    for f in findings:
        print(f)
    if findings:
        return 1
    print('wiki-gen: ' + ('all generated regions current' if not write
                          else 'regions written' if notes else 'nothing to change'))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
