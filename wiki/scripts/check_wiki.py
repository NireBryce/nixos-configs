#!/usr/bin/env python3
"""Static checks of wiki/ against the actual module tree, for authoritative
claims that silently go stale after a refactor -- a category moved, a host
stopped importing something. Same motivation as `flake/scripts/modules.py`:
nothing about `nix flake check` or `just modules` reads prose, so a wiki page
can say something the tree has stopped agreeing with and nothing catches it.

This does NOT replace human judgement about whether a change actually needs a
wiki update -- see skill `wiki-sync` for that. It only catches the mechanical
case: a claim that's phrased as a checkable fact (an import list, a path) and
no longer matches what's on disk. Historical claims ("added 2026-08-21 as
`nire/foo/`") are deliberately NOT the target -- this repo keeps those on
purpose (CLAUDE.md, "a bug recorded in a comment stays in the file"), and a
script can't tell historical prose from a live claim by itself, so it checks
structured, extractable facts only:

  imports   For each host's actual bare-category import list (parsed the same
            way `modules.py` parses aggregates) and each `wiki/categories/
            <name>.md` that exists for one of those categories, checks that
            the page's "## Imported by" section text mentions the host by
            name, and flags a host name mentioned there that the host's
            actual import list does not contain. Heuristic, not exact --
            prose is matched by substring, so a page phrasing a host's
            *absence* ("not durandal") will mention the name too; read a
            finding before trusting it, same as `modules.py`'s own tools ask.
            Categories with no wiki page (nirePackages/* subcategories,
            nireHost/* bundles -- see categories/README.md's own exclusion
            list) are silently skipped: nothing to check them against.

  check     Currently just `imports` -- kept as its own subcommand so a
            second mechanical check can be added later without another
            plumbing pass. A per-category file COUNT used to be one (a
            "Members" column in categories/README.md, and a duplicate,
            unchecked "N files across M subdirectories" line in
            categories/system.md) -- removed 2026-08-29 along with the
            counts themselves, once the toil of hand-incrementing them on
            every module add/remove outweighed what they told a reader that
            "read the directory" didn't already. See wiki-sync and this
            repo's existing "read the file directly for the current list
            rather than trusting a count here" idiom (CLAUDE.md, Safety) --
            the same reasoning applies to file counts as to host lists.

    check_wiki.py imports [repo-root]
    check_wiki.py check   [repo-root]

repo-root defaults to two directories up from this script (wiki/scripts/ ->
wiki/ -> repo root).
"""
import re, sys, pathlib

CATEGORY_FILE = 'dirsAsCategory.nix'
# Same shape as modules.py's AGG -- `with config.flake.modules.<class>; [ ... ]`,
# the form every host aggregate and every dirsAsCategory.nix output uses.
AGG = re.compile(r'with\s+config\.flake\.modules\.(\w+);\s*\[(.*?)\]', re.S)
COMMENT = re.compile(r'#[^\n]*')

# host short-name -> its nireHost/*-configuration.nix. lysithea is darwin-class;
# every other host is nixos-class. nire-installer and nire-llm-sandbox
# (removed 2026-08-27 and 2026-08-28 respectively -- see wiki/history.md; both
# were deliberately excluded even while they existed) are not listed here --
# CLAUDE.md's Architecture section is explicit that neither counted as "a
# host" the way these four do, and categories/README.md's "Imported by"
# columns never name either one. (nire-lego was a fifth real host here until
# its removal 2026-08-27 -- see wiki/history.md.)
HOSTS = ['durandal', 'tenacity', 'cube', 'lysithea']

IMPORTED_BY_HEADING = re.compile(r'^##\s+Imported by\s*$', re.M)
NEXT_HEADING = re.compile(r'^##\s+', re.M)


def repo_root(argv):
    if len(argv) > 1:
        return pathlib.Path(argv[1]).resolve()
    return pathlib.Path(__file__).resolve().parents[2]


def nested_category_names(categories, name):
    """`name` plus every category nested (at any depth) under its own
    directory -- e.g. `homelab` expands to itself plus `containers`,
    `git-forge`, ..., `virtualization`. Mirrors "nested categories overlap
    their parents on purpose" (flake/doc/dirsAsCategory.md): a host that
    imports the umbrella name effectively gets every module the nested ones
    do, so for the purposes of "does this host import category X" it counts
    as importing X too, even though X never appears literally in the host's
    own import list.
    """
    if name not in categories:
        return {name}
    result = {name}
    for child in categories[name].rglob(CATEGORY_FILE):
        if child.parent != categories[name]:
            result.add(child.parent.name)
    return result


def host_imports(root, categories):
    """host short-name -> set of category names it effectively imports --
    literal bare names from its own import list, expanded through any
    umbrella category among them (see nested_category_names)."""
    out = {}
    for host in HOSTS:
        p = root / 'flake' / 'modules' / 'nireHost' / f'{host}-configuration.nix'
        if not p.exists():
            print(f"WARN  expected host file missing: {p}")
            continue
        text = COMMENT.sub('', p.read_text())
        literal = set()
        for m in AGG.finditer(text):
            literal.update(re.findall(r'[\w-]+', m.group(2)))
        effective = set()
        for n in literal:
            effective |= nested_category_names(categories, n)
        out[host] = effective
    return out


def find_categories(root):
    """category name -> its directory, for every dirsAsCategory.nix under
    flake/modules/nire/ and flake/modules/nireUser/ -- the two areas
    categories/README.md actually indexes (nirePackages/* and nireHost/*
    are deliberately excluded there, see that file's own header, so this
    check has nothing to compare them against and doesn't look).
    """
    cats = {}
    for area in ('nire', 'nireUser'):
        base = root / 'flake' / 'modules' / area
        if not base.exists():
            continue
        for p in base.rglob(CATEGORY_FILE):
            cats[p.parent.name] = p.parent
    return cats


# "all four hosts" / "All three NixOS hosts" -- a page is allowed to claim
# blanket coverage in prose instead of naming every host individually. Two
# separate phrases because they cover different sets: "three NixOS hosts"
# means specifically {durandal, tenacity, cube} (lysithea is darwin,
# not NixOS), while "four hosts" means all of HOSTS including lysithea. A
# category can use the three-host phrase and still separately name lysithea
# by hand for a narrower reason (system.md, nix.md) -- so blanket coverage
# only removes hosts it actually covers from the per-host check below,
# rather than skipping that check entirely. (Before nire-lego's removal
# 2026-08-27 these were "four NixOS hosts" / "five hosts" -- renumbered,
# not renamed, since the phrases themselves are what pages actually say.)
ALL_NIXOS_HOSTS_PHRASE = re.compile(r'\ball\s+(?:three|3)\s+NixOS\s+hosts\b', re.I)
ALL_HOSTS_PHRASE = re.compile(r'\ball\s+(?:four|4)\s+hosts\b', re.I)
NIXOS_HOSTS = {'durandal', 'tenacity', 'cube'}


def check_imports(root):
    categories = find_categories(root)
    imports = host_imports(root, categories)
    cat_pages_dir = root / 'wiki' / 'categories'
    findings = []

    # category -> hosts that actually import it
    by_category = {}
    for host, names in imports.items():
        for n in names:
            by_category.setdefault(n, set()).add(host)

    for category, hosts in sorted(by_category.items()):
        page = cat_pages_dir / f'{category}.md'
        if not page.exists():
            continue  # no page to check this category against
        text = page.read_text()
        m = IMPORTED_BY_HEADING.search(text)
        if not m:
            findings.append(f"NO 'Imported by' SECTION  {page}")
            continue
        rest = text[m.end():]
        end = NEXT_HEADING.search(rest)
        section = rest[:end.start()] if end else rest

        covered = set()
        if ALL_NIXOS_HOSTS_PHRASE.search(section):
            covered |= NIXOS_HOSTS
        if ALL_HOSTS_PHRASE.search(section):
            covered |= set(HOSTS)

        # Hosts a blanket phrase already accounts for are satisfied; anything
        # left over (a host the blanket doesn't cover, or every host when
        # there's no blanket at all) still needs to appear by name.
        for host in hosts - covered:
            if host not in section:
                findings.append(
                    f"MISSING  {page}: '{category}' is imported by "
                    f"'{host}' but the host isn't named in Imported by")

        # reverse direction: a host named in the section this category's
        # actual importers don't include. Heuristic -- a page can legitimately
        # name a host to say it does NOT import the category ("not durandal").
        for host in HOSTS:
            if host in section and host not in hosts:
                findings.append(
                    f"REVIEW   {page}: '{host}' is named in Imported by but "
                    f"does not actually import '{category}' -- confirm this "
                    f"is phrased as an exclusion, not a stale inclusion")
    return findings


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'check'
    root = repo_root([sys.argv[0]] + sys.argv[2:])

    findings = []
    if cmd in ('imports', 'check'):
        findings += check_imports(root)
    if cmd not in ('imports', 'check'):
        print(__doc__)
        sys.exit(2)

    for f in findings:
        print(f)
    hard = [f for f in findings if not f.startswith('REVIEW')]
    if not findings:
        print(f"{cmd}: no findings")
    elif not hard:
        print(f"{cmd}: only REVIEW findings (heuristic, needs a human look; "
              f"see this script's own docstring) -- not failing on those alone")
    sys.exit(1 if hard else 0)


if __name__ == '__main__':
    main()
