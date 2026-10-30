"""The wiki's generated regions: the host table, the categories index
tables, the module-counts table, and the module-tree diagram.

The row sources read the same tree.py the checks do (nixtree.py's one
static reading), so a host added to hosts.nix appears in the table and in
the checks with no edit here. Region `source` strings are verbatim from
the tool that wrote the current regions: the marker line is part of the
rendered region, so these render byte-identically to what wiki_gen.py
wrote. `just wiki-gen` stays the writer; the `generated` check is the
lint over what it produces.

The module-layout diagram needs `nix run` against this checkout's flake,
declared as the region's capability: a machine without nix skips that one
region with a stated REVIEW finding while everything else still checks.

Config (factcheck.toml `[regions]`, all defaults shown):

    [regions]
    homelab = "homelab-config/homelab"
    pages-dir = "wiki/config-structure/categories"
    tailnet-template = "ts-{short}"
    wipes-import = "impermanence"
    wipes-darwin-label = "n/a"
"""
import re

from factcheck import genregions
from factcheck.config import Config
from factcheck.genregions import Block, GenError, Region

import tree

WIKI_GEN = '`just wiki-gen`'
CLASS_ORDER = ['nixos', 'homeManager', 'darwin']

DEFAULT_COUNT_ROWS = [
    {'label': 'total `.nix` files under `flake/modules/`'},
    {'label': 'header comment (`# This is a dirs-as-categories module…`)',
     'grep': '# This is a dirs-as-categories module file, which means'},
    {'label': '`# summary:` / `# package summary:` comment',
     'regex': r'(?m)^\s*# (?:package )?summary:'},
    {'label': '`with pkgs;` package lists', 'grep': 'with pkgs;'},
]


def _settings(root):
    s = {**Config(root).section('regions')}
    return {
        'class_order': s.get('class-order', CLASS_ORDER),
        'homelab': s.get('homelab', 'homelab-config/homelab'),
        'nested_max': int(s.get('nested-named-max', 3)),
        'pages': s.get('pages-dir', 'wiki/config-structure/categories'),
        'tailnet': s.get('tailnet-template', 'ts-{short}'),
        'wipes_import': s.get('wipes-import', 'impermanence'),
        'wipes_darwin': s.get('wipes-darwin-label', 'n/a'),
        'counts': s.get('module-counts', DEFAULT_COUNT_ROWS),
    }


def host_rows(root):
    """hosts.nix's `nire-*` entries in file order (forge-runner, a guest,
    has no `nire-` prefix and is excluded -- hosts.md says why). 'Wipes
    /root?' is whether the host's effective import list holds
    `impermanence`; darwin has no initrd stage this repo touches, hence
    n/a. A NixOS host that does not wipe is bold: it is the exception
    AGENTS.md's Safety section warns about."""
    st = _settings(root)
    categories = tree.find_categories(root)
    hosts = tree.actual_hosts(root)
    if not hosts:
        raise GenError('hosts.nix declares no nire-* hosts (or moved)')
    shorts = [n.removeprefix('nire-') for n in hosts]
    for s in shorts:
        p = root / 'flake/modules/host-config' / f'{s}-configuration.nix'
        if not p.exists():
            raise GenError(f'no {p.relative_to(root)} for nire-{s}')
    imports = tree.host_imports(root, categories, shorts)
    for name, cls in hosts.items():
        short = name.removeprefix('nire-')
        if cls == 'darwin':
            wipes = st['wipes_darwin']
        elif st['wipes_import'] in imports[short]:
            wipes = 'yes'
        else:
            wipes = '**no**'
        yield name, {'Host': f'`{name}`', 'Class': cls,
                     'Wipes `/root`?': wipes,
                     'Tailnet name': '`' + st['tailnet'].format(short=short)
                                     + '`'}


def category_rows(homelab):
    """Index table rows for every category with a wiki page: the homelab
    umbrella and its nested categories when `homelab`, everything else
    otherwise. Ordered by area then name. Directory notes nested
    categories; Class(es) is every class declared under the tree (what
    including this name actually wires in)."""
    def rows(root):
        st = _settings(root)
        modules = root / 'flake/modules'
        pages = root / st['pages']
        found = []
        for name, d in tree.find_categories(root).items():
            rel = d.relative_to(modules).as_posix()
            if (rel == st['homelab']
                    or rel.startswith(st['homelab'] + '/')) != homelab:
                continue
            if (pages / f'{name}.md').exists():
                link = f'{name}.md'
            elif (pages / name / '00-INDEX.md').exists():
                link = f'{name}/00-INDEX.md'
            else:
                continue  # no page, no row
            nested = sorted(c.name for c in tree.categories_under(root, d))
            dir_cell = f'`{rel}/`'
            if 0 < len(nested) <= st['nested_max']:
                dir_cell += ' (+ nested ' + ', '.join(f'`{n}`'
                                                      for n in nested) + ')'
            elif nested:
                dir_cell += f' (+ {len(nested)} nested)'
            classes = tree.category_classes(d)
            ordered = ([c for c in st['class_order'] if c in classes]
                       + sorted(classes - set(st['class_order'])))
            found.append(((rel.split('/')[0], name), name, {
                'Category': f'[{name}]({link})', 'Directory': dir_cell,
                'Class(es)': ', '.join(ordered)}))
        for _, name, cells in sorted(found, key=lambda t: t[0]):
            yield name, cells
    return rows


def count_rows(root):
    """One row per convention the module style guide once stated as an
    inline count (moved to the -for-agents sibling, generated since
    2026-10-01). The pattern is what the page's 'recompute by hand' grep
    uses; no pattern counts the files themselves."""
    st = _settings(root)
    files = sorted((root / 'flake/modules').rglob('*.nix'))
    if not files:
        raise GenError('no .nix files under flake/modules/')
    texts = [f.read_text() for f in files]
    for row in st['counts']:
        label, grep, regex = (row.get('label'), row.get('grep'),
                              row.get('regex'))
        if grep is None and regex is None:
            n = len(files)
        elif regex:
            n = sum(1 for t in texts if re.search(regex, t))
        else:
            n = sum(1 for t in texts if grep in t)
        yield label, {'What': label, 'Files': str(n)}


def module_layout(root):
    """Mermaid of the top of the module tree -- areas and their direct
    categories, no modules (per-category and per-host diagrams are
    on-demand output of `just module-graph`, not committed). The tree is
    the file-only reading (static_document; `just modules` keeps it in
    step with the evaluated graph), drawn by the flake-module-graph input
    through this checkout's own flake -- not the checked-out tree's, so a
    fixture tree needs no flake. Never evaluates `root`."""
    import json
    import subprocess
    modules = root / 'flake/modules'
    if not modules.is_dir():
        raise GenError('no flake/modules/ directory')
    doc = tree.static_document(root)
    if not doc['categories']:
        raise GenError('no categories under flake/modules/')
    flake = pathlib_path(__file__).resolve().parents[2] / 'flake'
    try:
        r = subprocess.run(
            ['nix', 'run', f'{flake}#module-graph', '--',
             'tree', '-', '--depth', '1', '--categories-only'],
            input=json.dumps(doc), capture_output=True, text=True)
    except FileNotFoundError:
        raise GenError('nix is not installed; the diagram is drawn by the '
                       'flake-module-graph input')
    if r.returncode:
        lines = r.stderr.strip().splitlines()
        raise GenError(
            f'module-graph failed: {lines[-1] if lines else r.returncode}')
    return '```mermaid\n' + r.stdout.rstrip('\n') + '\n```'


def pathlib_path(p):
    from pathlib import Path
    return Path(p)


def register():
    """Registers the regions. Called at import. The `source` strings are
    verbatim from wiki_gen.py's REGIONS -- the marker line is part of the
    rendered region, so byte-parity with what wiki_gen wrote needs these
    exact."""
    genregions.register(Region(
        'hosts-table', 'wiki/fleet/hosts.md',
        "flake/modules/host-config/hosts.nix and each host's import list",
        ['Host', 'Class', 'Role', 'Wipes `/root`?', 'Tailnet name'],
        'Host', ['Role'], host_rows, tool_name=WIKI_GEN))
    for name, homelab, source in (
            ('categories-index-system', False,
             'the categories under flake/modules/ and the pages in '
             'wiki/config-structure/categories/'),
            ('categories-index-homelab', True,
             'the categories under flake/modules/homelab-config/homelab/ '
             'and the pages in wiki/config-structure/categories/')):
        genregions.register(Region(
            name, 'wiki/config-structure/categories/00-INDEX.md', source,
            ['Category', 'Directory', 'Class(es)', 'Imported by'],
            'Category', ['Imported by'], category_rows(homelab),
            tool_name=WIKI_GEN))
    genregions.register(Region(
        'module-counts',
        'wiki/config-structure/module-style-guide-for-agents.md',
        'a count of the .nix files under flake/modules/',
        ['What', 'Files'], 'What', [], count_rows, tool_name=WIKI_GEN))
    genregions.register(Block(
        'module-layout', 'wiki/config-structure/architecture.md',
        'the categories under flake/modules/, drawn by the '
        'flake-module-graph input',
        module_layout, needs=('nix',), tool_name=WIKI_GEN))


register()
