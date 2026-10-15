#!/usr/bin/env python3
"""Draws the module tree: which categories exist, what sits in them, and which
host imports what -- the picture behind `modules.py`'s checks.

Which categories exist, and which folder each one is, come from the
collector itself: `nix eval --json ./flake#categoryGraph`, published by
_lib/category-collector.nix from the same walk that builds the import lists.
When that evaluation is unavailable (no nix, or the flake does not evaluate)
the tool says so on stderr and falls back to modules.py's static parse, which
finds categories by their shims; `--static` asks for that path outright, and
the wiki's generated diagram always uses it (wiki-lint runs no evaluation).
What a module declares (its classes) and what a host imports are parsed from
the files either way: evaluation keeps neither as names.

The model is one function, `graph(root)`, returning plain nodes and edges.
`select()` narrows it, and the three subcommands are thin renderers:

    module-graph.py tree  <modules-dir> [filters]   # category -> module tree, Mermaid
    module-graph.py hosts <modules-dir> [filters]   # host -> categories it imports, Mermaid;
                                                    # top-down, each host's host-config/ and
                                                    # users-config/ categories above it,
                                                    # shared ones below, --wrap N per row
    module-graph.py dot   <modules-dir> [filters] [--view tree|hosts]   # Graphviz
    module-graph.py html  <modules-dir> [filters]   # the hosts view as an interactive page:
                                                    # click hosts to show only what they reach

Filters (a few hundred modules in one diagram is unreadable):

    --category NAME     only that category and what is nested in it; for `hosts`,
                        also only the hosts that import something in it
    --depth N           directory levels below the diagram's roots: areas (or the
                        --category) are level 0, what sits directly in them level 1
    --categories-only   leave out modules and the plain folders holding them

    --static            read categories from the files only; no `nix eval`
    --verify            also check the static parse against evaluation: categories,
                        folders, files and nesting against categoryGraph, and module
                        names against `nix eval .#modules.<class>`; slow, off by default

Colour standard (PALETTE below holds it). Importable categories -- a
directory holding a dirsAsCategory.nix, which a host can name -- are blue
rounded cards, reached by dotted edges; one that holds nested categories is
a pale blue box around them instead (boxed()), titled like its card. Implicit folders -- plain
directories inside a category, collected only through it -- are slate and
square-cornered. Modules are white, including one a host names directly:
importable means a category, never a single module. Host and home entry
points are white with one hue each, shared by their import edges.

Annotations. `n` `h` `d` are the classes a module declares (nixos, homeManager,
darwin); a category shows the union over everything beneath it and a module
count. A category is drawn as an orphan when no host or aggregate reaches it
(modules.py's `orphans`, as a picture) and dashed when it is reached only
through modules named individually (`desktop-env`, by way of `kde-desktop`).
A module named like a category, or like another module of the same class, gets
a `merges` edge to it: same-named declarations merge, which is how `boot` came
to mean two things.

Reachability reads the same imports modules.py does, including
`config.flake.modules.<class>.<name>` references; only the `with ...; [ ]`
aggregate lists are drawn as host edges.
"""
import argparse, html, json, pathlib, re, subprocess, sys
from dataclasses import dataclass

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import modules as mod  # noqa: E402

CLASS_LETTER = {'nixos': 'n', 'homeManager': 'h', 'darwin': 'd'}
# An aggregate's own declaration, with or without `.imports`:
# `flake.modules.nixos.cubeConfiguration.imports =` and
# `flake.modules.nixos.tenacityConfiguration = {` both name one.
AGG_DECL = re.compile(r'(?<!config\.)flake\.modules\.(\w+)\.([\w-]+)(?:\.imports)?\s*=')
CLASS_ORDER = list(CLASS_LETTER)


@dataclass(frozen=True)
class Node:
    id: str
    kind: str                # area | category | folder | module | aggregate | missing
    label: str
    classes: frozenset = frozenset()
    count: int = 0           # category, folder: modules beneath, nested categories included
    status: str = ''         # category: imported | inherited | by-module | orphan
    merges: bool = False     # shares its name with a category or a same-class module


@dataclass(frozen=True)
class Edge:
    src: str
    dst: str
    kind: str                # contains | imports | merges | enables
    cls: str = ''            # imports: the class of the aggregate that lists it


@dataclass
class Graph:
    nodes: dict              # id -> Node, in insertion order
    edges: list
    roots: list              # ids the `contains` tree hangs from


def letters(classes):
    known = [CLASS_LETTER[c] for c in CLASS_ORDER if c in classes]
    return ' '.join(known + sorted(c for c in classes if c not in CLASS_LETTER))


def graph(root, evaluated=None):
    """The whole model. `evaluated` is flake.categoryGraph (see
    evaluated_categories()); without it, categories come from the static
    scan. Module classes and host imports are parsed from files either way."""
    root = pathlib.Path(root)
    scanned, by_name = mod.scan(root)
    if evaluated is None:
        catdir_of = {name: p.parent for name, p in scanned.items()}
    else:
        catdir_of = {name: root / v['dir'] for name, v in evaluated.items()}
    catdirs = {d: name for name, d in catdir_of.items()}
    # A plain directory inside a category: no shim, so no host can name it --
    # its modules arrive only through the category above it (the collector
    # walks into it). Drawn as its own node so the two kinds of directory can
    # be told apart; `_` paths are already out of `entries`.
    entries = sorted((p, n, c) for n, es in by_name.items() for p, c in es)
    folderdirs = sorted({d for p, _, _ in entries for d in p.parents
                         if d not in catdirs and catdirs.keys() & set(d.parents)})
    imported = mod.imported_names(root)
    all_imported = set().union(*imported.values()) if imported else set()

    nodes, edges, roots = {}, [], []

    def rel(p):
        return p.relative_to(root).as_posix()

    def area(path):
        parts = path.relative_to(root).parts
        name = parts[0] if len(parts) > 1 else root.name
        node = nodes.setdefault(f'area:{name}', Node(f'area:{name}', 'area', name))
        if node.id not in roots:
            roots.append(node.id)
        return node.id

    def parent_of(path):
        """Nearest enclosing category or folder, else the area directory."""
        for anc in path.parents:
            if anc in catdirs:
                return f'cat:{rel(anc)}'
            if anc in folderdirs:
                return f'dir:{rel(anc)}'
        return area(path)

    def beneath(d):
        return [e for e in entries if d in e[0].parents]

    def merges(path, name, classes):
        same = [p for p, c in by_name[name] if p != path and c & classes]
        return name in catdir_of or bool(same)

    for d, name in sorted(catdirs.items()):
        subtree = beneath(d)
        classes = frozenset().union(*(c for _, _, c in subtree)) if subtree else frozenset()
        if name in all_imported:
            status = 'imported'
        elif any(n in all_imported for dd, n in catdirs.items() if dd in d.parents):
            status = 'inherited'
        elif any(n in all_imported for _, n, _ in subtree):
            status = 'by-module'
        else:
            status = 'orphan'
        nodes[f'cat:{rel(d)}'] = Node(f'cat:{rel(d)}', 'category', name, classes,
                                      len(subtree), status, name in by_name)

    for d in folderdirs:
        subtree = beneath(d)
        nodes[f'dir:{rel(d)}'] = Node(f'dir:{rel(d)}', 'folder', d.name,
                                      frozenset().union(*(c for _, _, c in subtree)),
                                      len(subtree))

    for path, name, classes in entries:
        nodes[f'mod:{rel(path)}'] = Node(f'mod:{rel(path)}', 'module', name,
                                         frozenset(classes), merges=merges(path, name, classes))

    # containment last, so area nodes are created in a stable order
    for nid, n in list(nodes.items()):
        if n.kind in ('category', 'folder', 'module'):
            path = root / nid.split(':', 1)[1]
            edges.append(Edge(parent_of(path), nid, 'contains'))
    for path, name, classes in entries:
        if name in catdir_of:
            edges.append(Edge(f'mod:{rel(path)}', f'cat:{rel(catdir_of[name])}', 'merges'))
        for p2, c2 in by_name[name]:
            if p2 > path and c2 & classes:
                edges.append(Edge(f'mod:{rel(path)}', f'mod:{rel(p2)}', 'merges'))

    aggregate_list = mod.aggregates(root)
    for path, cls, listed in aggregate_list:
        aid = f'agg:{rel(path)}:{cls}'
        nodes.setdefault(aid, Node(aid, 'aggregate', path.stem, frozenset([cls])))
        for name in dict.fromkeys(listed):
            if name in catdir_of:
                targets = [f'cat:{rel(catdir_of[name])}']
            elif name in by_name:
                targets = [f'mod:{rel(p)}' for p, c in by_name[name]]
            else:
                targets = [f'missing:{name}']
                nodes.setdefault(targets[0], Node(targets[0], 'missing', name))
            edges += [Edge(aid, t, 'imports', cls) for t in targets]
    edges += enables(root, aggregate_list, catdir_of, entries, by_name, beneath, rel)
    return Graph(nodes, edges, roots)


def enables(root, aggregate_list, catdir_of, entries, by_name, beneath, rel):
    """`enables` edges: aggregate A -> aggregate B when a module A reaches
    refers to B by name. That is how a host gets its Home Manager config:
    it imports no `ellyHomeManager`; it imports `system`, which holds
    enable-home-manager.nix, which refers to
    `config.flake.modules.homeManager.ellyHomeManager`.

    A reaches a file of its own class that sits under a category it imports,
    or is a module it imports by name, or its own file -- so a NixOS host
    importing `system` gets enable-home-manager.nix, not the darwin twin."""
    declared = {}                    # (class, declared name) -> aggregate id
    for path, cls, _ in aggregate_list:
        for c, name in AGG_DECL.findall(mod.COMMENT.sub('', path.read_text())):
            if c == cls:
                declared[(cls, name)] = f'agg:{rel(path)}:{cls}'
                break
    refs = {}

    def refs_of(p):
        if p not in refs:
            refs[p] = set(mod.REF.findall(mod.COMMENT.sub('', p.read_text())))
        return refs[p]

    out = []
    for path, cls, listed in aggregate_list:
        aid = f'agg:{rel(path)}:{cls}'
        files = {path}
        for name in listed:
            if name in catdir_of:
                files |= {p for p, _, c in beneath(catdir_of[name]) if cls in c}
            files |= {p for p, c in by_name.get(name, []) if cls in c}
        targets = sorted({declared[r] for f in files for r in refs_of(f)
                          if r in declared and declared[r] != aid})
        out += [Edge(aid, target, 'enables', cls) for target in targets]
    return out


def children(g):
    out = {}
    for e in g.edges:
        if e.kind == 'contains':
            out.setdefault(e.src, []).append(e.dst)
    for kids in out.values():
        kids.sort(key=lambda i: (g.nodes[i].kind != 'category', g.nodes[i].label, i))
    return out


def select(g, view='tree', category=None, depth=None, categories_only=False):
    """The subgraph a diagram draws. `view` is 'tree' (containment) or 'hosts'
    (aggregates and what they import; categories only, nesting dotted in)."""
    kids = children(g)
    if category is None:
        starts = list(g.roots)
    else:
        starts = [i for i, n in g.nodes.items() if n.kind == 'category' and n.label == category]
        if not starts:
            known = ', '.join(sorted({n.label for n in g.nodes.values() if n.kind == 'category'}))
            raise SystemExit(f"error: no category {category!r}; categories: {known}")
    keep, level, queue = [], {}, [(s, 0) for s in starts]
    while queue:
        i, d = queue.pop(0)
        if i in level or (depth is not None and d > depth):
            continue
        level[i] = d
        keep.append(i)
        queue += [(k, d + 1) for k in kids.get(i, [])]
    # Overviews leave out what a host cannot name: modules and the plain
    # folders holding them. A category nested in a hidden folder hangs off
    # the nearest directory still drawn.
    overview = categories_only or view == 'hosts'
    keep = [i for i in keep if not (overview and g.nodes[i].kind in ('module', 'folder'))]
    parent = {e.dst: e.src for e in g.edges if e.kind == 'contains'}

    def up(i, shown):
        p = parent.get(i)
        while p is not None and p not in shown:
            p = parent.get(p)
        return p

    def containment(order, shown):
        return [Edge(up(i, shown), i, 'contains') for i in order if up(i, shown) is not None]

    if view == 'tree':
        shown = set(keep)
        edges = containment(keep, shown) + [e for e in g.edges if e.kind == 'merges'
                                            and e.src in shown and e.dst in shown]
        return Graph({i: g.nodes[i] for i in keep}, edges, [s for s in starts if s in shown])

    # hosts: every category in range (in its area's container), plus the
    # aggregates that import into it
    shown = {i for i in keep if g.nodes[i].kind in ('category', 'area')}
    imports = []
    for e in g.edges:
        if e.kind != 'imports' or e.dst not in g.nodes:
            continue
        if g.nodes[e.dst].kind == 'module':
            # a module imported by name (kde-desktop): drawn when its category is
            if category is not None and up(e.dst, shown) is None:
                continue
            shown.add(e.dst)
            imports.append(e)
        elif e.dst in shown or (category is None and g.nodes[e.dst].kind == 'missing'):
            imports.append(e)
    used = {e.src for e in imports}
    nodes = {i: n for i, n in g.nodes.items()
             if i in shown or (n.kind == 'aggregate' and i in used)
             or (n.kind == 'missing' and any(e.dst == i for e in imports))}
    enabled = [e for e in g.edges if e.kind == 'enables'
               and e.src in nodes and e.dst in nodes]
    return Graph(nodes, containment(list(nodes), shown) + imports + enabled, [])


# --- renderers ------------------------------------------------------------
#
# The look follows nix-topology's: rounded cards with a muted fill and a
# darker outline of the same hue, a bold name over a quiet subtitle, and
# containers with a small title to group what belongs together. Fills are
# light and the text dark on purpose, so a diagram reads the same on a white
# page and on GitHub's dark theme.

INK, QUIET, LINE = '#1e293b', '#64748b', '#94a3b8'
# The colour standard, kind -> (fill, outline). One rule carries it: a
# directory holding a dirsAsCategory.nix is an IMPORTABLE category -- a host
# can name it -- and is the only thing drawn in blue, as a rounded card. A
# plain directory inside one is IMPLICIT, collected only through the
# category above it: slate, square-cornered (Graphviz: a folder). Modules
# are neutral white whether or not some host names one directly
# (kde-desktop); importable here means a category, never a single module.
PALETTE = {
    'area':      ('#f8fafc', '#cbd5e1'),
    'category':  ('#dbeafe', '#2563eb'),
    'folder':    ('#f1f5f9', '#94a3b8'),
    'module':    ('#ffffff', '#94a3b8'),
    'aggregate': ('#ffffff', '#f59e0b'),
    'missing':   ('#fee2e2', '#ef4444'),
}
ALERT = ('#fff1f2', '#e11d48')      # an orphan category, or a name that merges
# One hue per host or home entry point, for its card outline and every import
# edge it draws -- nix-topology's colour-per-network, so one host's imports can
# be followed through the crossing lines. Cycled past six. No blue and no
# red: blue is the importable-category colour and red the alert, and a host
# drawn in either reads as one of those.
HUES = ['#16a34a', '#d97706', '#9333ea', '#db2777', '#0d9488', '#92400e']


def hues(g):
    aggs = [i for i, n in g.nodes.items() if n.kind == 'aggregate']
    return {a: HUES[k % len(HUES)] for k, a in enumerate(aggs)}


def colours(n):
    if n.kind != 'missing' and (n.merges or n.status == 'orphan'):
        return ALERT
    return PALETTE[n.kind]


def parts(n):
    """(title, subtitle) of a node's card."""
    if n.kind in ('category', 'folder'):
        return n.label + '/', ' · '.join(x for x in (letters(n.classes), str(n.count)) if x)
    if n.kind == 'module':
        return n.label, letters(n.classes)
    if n.kind == 'missing':
        return n.label, 'no such module'
    if n.kind == 'aggregate':
        return n.label, ', '.join(c for c in CLASS_ORDER if c in n.classes)
    return n.label, ''


@dataclass
class Box:
    """A container a diagram draws: an area, the host and home entry points,
    or a category that holds a nested category."""
    id: str                  # the area or category node id; 'grp:entry' for the hosts
    kind: str                # area | category | entry
    items: list              # node ids drawn directly inside
    subs: list               # Boxes nested inside
    top: list                # direct children, in order: what wrapping lays out in rows


def children_of(g):
    kids = {}
    for e in g.edges:
        if e.kind == 'contains':
            kids.setdefault(e.src, []).append(e.dst)
    return kids


def boxed(g):
    """Categories drawn as a container rather than a card: those with a
    nested category drawn directly under them (development holds langs and
    tools). Their own `contains` edges become the containment, as an
    area's do."""
    kids = children_of(g)
    return {i for i, n in g.nodes.items() if n.kind == 'category'
            and any(g.nodes[k].kind == 'category' for k in kids.get(i, []))}


def boxes(g):
    """The container tree: one Box per area, holding everything beneath it
    -- a boxed category as a nested Box, anything else as an item -- then
    the host and home entry points together, in the hosts view."""
    kids, cats = children_of(g), boxed(g)

    def build(i):
        b = Box(i, g.nodes[i].kind, [], [], list(kids.get(i, [])))
        queue = list(kids.get(i, []))
        while queue:
            m = queue.pop(0)
            if m in cats:
                b.subs.append(build(m))
            else:
                b.items.append(m)
                queue += kids.get(m, [])
        return b

    out = [build(i) for i, n in g.nodes.items() if n.kind == 'area']
    entry = [i for i, n in g.nodes.items() if n.kind == 'aggregate']
    if entry:
        out.append(Box('grp:entry', 'entry', entry, [], entry))
    return out


def walk(tree):
    for b in tree:
        yield b
        yield from walk(b.subs)


def rep(i, index):
    """The node an edge or a layout link uses for `i`: a boxed category is
    reached through the first thing in its box."""
    while i in index:
        i = index[i].top[0]
    return i


def arrows(g):
    """The edges drawn as arrows: everything but the containment an area or
    a boxed category draws as a box."""
    inside = boxed(g)
    return [e for e in g.edges
            if not (e.kind == 'contains' and (g.nodes[e.src].kind == 'area' or e.src in inside))]


# The hosts view runs top-down, imports flowing down from the hosts --
# except into the per-host and per-user directories (host-config/<host>/,
# users-config/<user>/: where-modules-go.md's "host-specific" and
# "user-specific" places), which are drawn ABOVE the hosts: they are what a
# host and its user are, not something pulled in from the shared tree.
TOP_AREAS = ('host-config', 'users-config')
# The shared areas below the hosts wrap their categories at this many per
# row (`--wrap`; 0 for one row), a boxed category's nested ones too --
# otherwise general-config alone is a row of ten, packages-config seven.
WRAP = 5


def hosts_view(g):
    return any(n.kind == 'aggregate' for n in g.nodes.values())


def area_of(i):
    return i.split(':', 1)[1].split('/')[0]


def upward(g, e):
    """An import into a category under TOP_AREAS: drawn pointing up."""
    return (e.kind == 'imports' and g.nodes[e.dst].kind == 'category'
            and area_of(e.dst) in TOP_AREAS)


def layout_links(g, wrap=WRAP):
    """[(first host, card, rank)]: invisible links that place every card in
    a shared area exactly `rank` ranks below the hosts -- shared by both
    renderers so they cannot disagree.

    Each shared area's categories are cut into rows of `wrap`; row r sits
    below row r-1 by that row's tallest entry, where a card is one rank and
    a boxed category the sum of its own rows (a box takes no rank of its
    own; its rows start where it does). Every card gets a link, not only
    the first of a row: a card in a box beside the one its host edges land
    on (text-tools, next to terminal-multiplexer in shell-apps) has no
    other edge at all, and Graphviz floats an unconstrained node to the top
    rank. The same link holds a category nothing imports whole
    (desktop-env) below the hosts instead of beside them."""
    if not hosts_view(g):
        return []
    tree = boxes(g)
    index = {b.id: b for b in walk(tree) if b.kind == 'category'}
    first = next(i for i, n in g.nodes.items() if n.kind == 'aggregate')

    def rows(items):
        if wrap <= 0:
            return [items] if items else []
        return [items[k:k + wrap] for k in range(0, len(items), wrap)]

    def height(i):
        if i not in index:
            return 1
        return sum(max(height(c) for c in r) for r in rows(index[i].top))

    links = []

    def place(top, rank):
        for row in rows(top):
            for i in row:
                if i in index:
                    place(index[i].top, rank)
                else:
                    links.append((first, i, rank))
            rank += max(height(i) for i in row)

    for b in tree:
        if b.kind == 'area' and g.nodes[b.id].label not in TOP_AREAS:
            place(b.top, 1)
    return links


def esc(text):
    return text.replace('"', '#quot;')


MERMAID_INIT = ('%%{init: {"theme": "base", "themeVariables": {"fontFamily": '
                '"ui-sans-serif, system-ui, sans-serif", "fontSize": "14px", '
                f'"lineColor": "{LINE}"}}, "flowchart": {{"curve": "basis", '
                '"nodeSpacing": 24, "rankSpacing": 80, "padding": 14}}}%%')
# A boxed category's container: the category colours, paler, so the cards
# inside it still stand out.
BOX_FILL = '#eff6ff'
ENTRY = ('#fefce8', '#fde68a')


def box_look(g, b):
    """(fill, outline, dashed, alert) for a container."""
    if b.kind == 'area':
        return (*PALETTE['area'], False, False)
    if b.kind == 'entry':
        return (*ENTRY, False, False)
    n = g.nodes[b.id]
    alert = colours(n) == ALERT
    return BOX_FILL, colours(n)[1], n.status == 'by-module', alert


def mermaid(g, wrap=WRAP):
    ids = {i: f'n{k}' for k, i in enumerate(g.nodes)}
    shape = {'category': '({})', 'folder': '[{}]', 'module': '([{}])', 'aggregate': '[[{}]]',
             'missing': '{{{{{}}}}}', 'area': '[{}]'}

    def card(i):
        n = g.nodes[i]
        title, sub = parts(n)
        text = f'<b>{title}</b>' + (f'<br/><i>{sub}</i>' if sub else '')
        return f'{ids[i]}{shape[n.kind].format(chr(34) + esc(text) + chr(34))}'

    hue, drawn, tree = hues(g), arrows(g), boxes(g)
    index = {b.id: b for b in walk(tree) if b.kind == 'category'}
    sid, styles = {}, []

    def emit(b, pad):
        if not (b.items or b.subs):
            return []
        name = sid[b.id] = f'g{len(sid)}'
        if b.kind == 'category':
            title, sub = parts(g.nodes[b.id])
            text = f'<b>{title}</b>' + (f' · <i>{sub}</i>' if sub else '')
        else:
            text = g.nodes[b.id].label if b.kind == 'area' else 'hosts and home'
        fill, line, dashed, alert = box_look(g, b)
        styles.append(f'    style {name} fill:{fill},stroke:{line},'
                      f'color:{INK if b.kind == "category" else QUIET}'
                      + (',stroke-width:2.5px' if alert else '')
                      + (',stroke-dasharray:5 3' if dashed else ''))
        out = [f'{pad}subgraph {name}["{esc(text)}"]']
        out += [f'{pad}    {card(m)}' for m in b.items]
        for s in b.subs:
            out += emit(s, pad + '    ')
        return out + [f'{pad}end']

    def end(i):
        return sid[i] if i in index else ids[i]

    lines = [MERMAID_INIT, f'flowchart {"TB" if hosts_view(g) else "LR"}']
    # Mermaid stacks unconnected containers bottom-up; reversed, the areas
    # read top-down in the order the tree lists them.
    for b in (tree[::-1] if not drawn else tree):
        lines += emit(b, '    ')
    inside = {m for b in walk(tree) for m in b.items}
    lines += [f'    {card(i)}' for i, n in g.nodes.items()
              if i not in inside and i not in index and n.kind != 'area']
    # Mermaid has no reversed arrow and ranks by edge direction, so an
    # upward import is a plain `category --- host` line in the host's
    # colour: written category-first, it ranks the category above. (An
    # invisible `category ~~~ host` plus the real arrow was tried: each pair
    # is a cycle, and with elly/ imported by every host, dagre broke the
    # cycles inconsistently and lifted a host out of its row.)
    by_hue = {}
    for k, e in enumerate(drawn):
        a, b = end(e.src), end(e.dst)
        if upward(g, e):
            lines.append(f'    {b} --- {a}')
            by_hue.setdefault(hue[e.src], []).append(str(k))
        elif e.kind == 'contains':
            # into a category: dotted, since it is importable on its own too
            nested = g.nodes[e.dst].kind == 'category'
            lines.append(f'    {a} {"-.->" if nested else "-->"} {b}')
        elif e.kind == 'merges':
            lines.append(f'    {a} -. merges .- {b}')
        elif e.kind == 'enables':
            # dashed: not an import -- a module the host imports turns it on
            lines.append(f'    {a} -. enables .-> {b}')
            by_hue.setdefault(hue[e.src], []).append(str(k))
        else:
            lines.append(f'    {a} --> {b}')
            by_hue.setdefault(hue[e.src], []).append(str(k))
    # Layout links last: every linkStyle index above is already fixed. In
    # Mermaid each `~` past three is one more rank between the two ends.
    lines += [f'    {ids[a]} {"~" * (minlen + 2)} {ids[b]}' for a, b, minlen in layout_links(g, wrap)]
    lines += [f'    linkStyle {",".join(v)} stroke:{h},stroke-width:1.5px'
              for h, v in by_hue.items()]
    lines += styles
    lines += [f'    style {ids[a]} stroke:{h},stroke-width:2px' for a, h in hue.items()]
    for kind in PALETTE:
        fill, line = PALETTE[kind]
        lines.append(f'    classDef {kind} fill:{fill},stroke:{line},color:{INK},stroke-width:1.5px')
    lines += [f'    classDef orphan fill:{ALERT[0]},stroke:{ALERT[1]},color:{INK},stroke-width:2.5px',
              f'    classDef bymodule stroke-dasharray:5 3',
              f'    classDef merges stroke:{ALERT[1]},stroke-width:2.5px']
    members = {}
    for i, n in g.nodes.items():
        if n.kind == 'area' or i in index:
            continue
        for s in style(n):
            members.setdefault(s, []).append(ids[i])
    lines += [f'    class {",".join(v)} {k}' for k, v in members.items()]
    return '\n'.join(lines)


def style(n):
    out = [n.kind]
    if n.kind == 'category' and n.status in ('orphan', 'by-module'):
        out.append(n.status.replace('-', ''))
    if n.merges:
        out.append('merges')
    return out


GRID = 4      # cards per row in an arrowless Graphviz diagram


def dot(g, wrap=WRAP):
    ids = {i: f'n{k}' for k, i in enumerate(g.nodes)}
    hue, drawn, tree = hues(g), arrows(g), boxes(g)
    index = {b.id: b for b in walk(tree) if b.kind == 'category'}
    cluster = {}

    def card(i):
        n = g.nodes[i]
        title, sub = parts(n)
        fill, line = colours(n)
        label = f'<b>{html.escape(title)}</b>'
        if sub:
            label += f'<br/><font point-size="9" color="{QUIET}">{html.escape(sub)}</font>'
        attrs = [f'label=<{label}>', f'fillcolor="{fill}"',
                 f'color="{hue.get(i, line)}"']
        if n.kind == 'module':
            attrs.append('shape=box style="rounded,filled"')
        if n.kind == 'folder':
            attrs.append('shape=folder style=filled')
        if n.kind == 'aggregate':
            attrs.append('shape=box style="rounded,filled" penwidth=1.6')
        if n.kind == 'category' and n.status == 'orphan' or n.merges:
            attrs.append('penwidth=2.5')
        if n.kind == 'category' and n.status == 'by-module':
            attrs.append('style="rounded,filled,dashed"')
        return f'{ids[i]} [{" ".join(attrs)}];'

    def emit(b, pad):
        if not (b.items or b.subs):
            return []
        name = cluster[b.id] = f'cluster_{len(cluster)}'
        fill, line, dashed, alert = box_look(g, b)
        if b.kind == 'category':
            title, sub = parts(g.nodes[b.id])
            label = (f'<b>{html.escape(title)}</b>'
                     + (f'  <font point-size="9" color="{QUIET}">{html.escape(sub)}</font>' if sub else ''))
        else:
            text = g.nodes[b.id].label if b.kind == 'area' else 'hosts and home'
            label = f'<font color="{QUIET}" point-size="10">{html.escape(text)}</font>'
        out = [f'{pad}subgraph {name} {{',
               f'{pad}    label=<{label}>;',
               f'{pad}    style="rounded,filled{",dashed" if dashed else ""}"; fillcolor="{fill}"; '
               f'color="{line}"; penwidth={2.5 if alert else 1.2}; margin=14;']
        out += [f'{pad}    {card(m)}' for m in b.items]
        if not drawn:
            out += [f'{pad}    {ids[x]} -> {ids[y]} [style=invis];'
                    for x, y in zip(b.items, b.items[GRID:])]
        for s in b.subs:
            out += emit(s, pad + '    ')
        return out + [f'{pad}}}']

    def edge(src, dst, attrs):
        """An edge whose ends may be boxes: drawn to the box's first node
        and clipped at the box (compound=true)."""
        attrs = list(attrs)
        if src in index:
            attrs.append(f'ltail={cluster[src]}')
        if dst in index:
            attrs.append(f'lhead={cluster[dst]}')
        a, b = ids[rep(src, index)], ids[rep(dst, index)]
        return f'    {a} -> {b}' + (f' [{" ".join(attrs)}];' if attrs else ';')

    # With no arrows (areas and their categories only) a left-to-right layout
    # stacks every card in one column; top-down plus invisible edges every
    # GRID cards lays each area out as a grid instead.
    # The hosts view runs top-down (TOP_AREAS above the hosts, see upward()).
    lines = ['digraph modules {',
             f'    rankdir={"LR" if drawn and not hosts_view(g) else "TB"}; bgcolor="white"; nodesep=0.22; '
             f'ranksep={0.9 if drawn else 0.3}; splines=true; newrank=true; compound=true;',
             f'    node [shape=box style="rounded,filled" fontname="Helvetica" fontsize=11 '
             f'fontcolor="{INK}" penwidth=1.3 margin="0.16,0.08"];',
             f'    edge [color="{LINE}" fontname="Helvetica" fontsize=9 fontcolor="{QUIET}" '
             f'arrowsize=0.7];']
    for b in tree:
        lines += emit(b, '    ')
    inside = {m for b in walk(tree) for m in b.items}
    lines += [f'    {card(i)}' for i, n in g.nodes.items()
              if i not in inside and i not in index and n.kind != 'area']
    lines += [f'    {ids[a]} -> {ids[b]} [style=invis minlen={minlen}];'
              for a, b, minlen in layout_links(g, wrap)]
    if hosts_view(g):
        # One row of hosts. Without it a host whose imports all sit in a
        # lower wrapped row (lysithea: nix, system, macos) is pulled down
        # to them -- Graphviz shortens edges, it does not keep rows.
        lines.append('    { rank=same; ' + ' '.join(
            ids[i] for i, n in g.nodes.items() if n.kind == 'aggregate') + ' }')
    for e in drawn:
        if e.kind == 'contains':
            nested = g.nodes[e.dst].kind == 'category'
            lines.append(edge(e.src, e.dst, ['style=dotted'] if nested else []))
        elif e.kind == 'merges':
            lines.append(edge(e.src, e.dst, [f'label="merges" color="{ALERT[1]}"',
                                             f'fontcolor="{ALERT[1]}" style=dashed dir=none']))
        elif e.kind == 'enables':
            lines.append(edge(e.src, e.dst, [f'color="{hue[e.src]}" style=dashed penwidth=1.2',
                                             'label="enables"', f'fontcolor="{hue[e.src]}"']))
        elif upward(g, e):
            # reversed for ranking, arrowhead kept on the category
            lines.append(edge(e.dst, e.src, [f'dir=back color="{hue[e.src]}" penwidth=1.2']))
        else:
            lines.append(edge(e.src, e.dst, [f'color="{hue[e.src]}" penwidth=1.2']))
    lines.append('}')
    return '\n'.join(lines)


# --- the interactive page --------------------------------------------------
#
# `html` renders the hosts view as one self-contained page (template:
# module-graph.html, beside this file). Python decides what is in the model
# and how each kind looks -- the same PALETTE, hues and parts() the other
# renderers use -- and the page only lays it out and filters it, so the
# page cannot disagree with them.

TEMPLATE = pathlib.Path(__file__).with_name('module-graph.html')
# Where the page puts each area relative to the hosts: a host's own
# directory behind them (above, or to the left), the user's own directory
# and the Home Manager config the hosts enable ahead of them, then the
# shared areas. (The Mermaid and Graphviz hosts views keep TOP_AREAS.)
BEHIND_AREAS = ('host-config',)
USER_AREAS = ('users-config',)
PLACEHOLDER = '/*@DATA@*/null'


def page_data(g):
    """The page's model, from a hosts-view graph: areas holding everything
    beneath them as a tree (each with its `place`: behind, user or shared),
    the hosts and the Home Manager configs they enable ("homes": aggregates
    another aggregate enables), each with its hue, what each imports, and
    which homes each host enables. A name a host imports that no module
    declares goes in its own 'not found' area, as in the other views."""
    kids, hue = children_of(g), hues(g)

    def node(i):
        n = g.nodes[i]
        title, sub = parts(n)
        out = {'id': i, 'kind': n.kind, 'title': title, 'sub': sub}
        if n.kind == 'category':
            out['status'] = n.status
        if n.merges:
            out['merges'] = True
        children = [node(c) for c in kids.get(i, []) if c in g.nodes]
        if children:
            out['children'] = children
        return out

    areas = []
    for i, n in g.nodes.items():
        if n.kind == 'area' and kids.get(i):
            area = node(i)
            area['place'] = ('behind' if n.label in BEHIND_AREAS
                             else 'user' if n.label in USER_AREAS else 'shared')
            areas.append(area)
    missing = [i for i, n in g.nodes.items() if n.kind == 'missing']
    if missing:
        areas.append({'id': 'area:(not found)', 'kind': 'area', 'title': 'not found',
                      'sub': '', 'place': 'shared', 'children': [node(i) for i in missing]})
    enabled = {e.dst for e in g.edges if e.kind == 'enables'}
    card = lambda a: {'id': a, 'title': parts(g.nodes[a])[0], 'sub': parts(g.nodes[a])[1],
                      'hue': hue[a]}
    hosts = [card(a) for a in hue if a not in enabled]
    homes = [card(a) for a in hue if a in enabled]
    imports = {a: [e.dst for e in g.edges if e.kind == 'imports' and e.src == a] for a in hue}
    enables = {a: [e.dst for e in g.edges if e.kind == 'enables' and e.src == a] for a in hue}
    style = {'palette': {k: list(v) for k, v in PALETTE.items()}, 'alert': list(ALERT),
             'boxFill': BOX_FILL}
    return {'areas': areas, 'hosts': hosts, 'homes': homes, 'imports': imports,
            'enables': enables, 'style': style}


def page(g):
    """The template with the model filled in. `</` is escaped so no name in
    the data can end the <script> element it sits in."""
    data = json.dumps(page_data(g), separators=(',', ':')).replace('</', '<\\/')
    text = TEMPLATE.read_text()
    if text.count(PLACEHOLDER) != 1:
        raise SystemExit(f'error: {TEMPLATE} must hold {PLACEHOLDER} exactly once')
    return text.replace(PLACEHOLDER, data)


# --- evaluation -----------------------------------------------------------

def evaluate(root, attr, run=subprocess.run):
    """(value, None) for `nix eval --json path:<flake>#<attr>`, or (None, why).
    `path:` rather than the git flake, so untracked files count -- the same
    files this tool parses -- instead of silently vanishing."""
    flake = pathlib.Path(root).resolve().parent
    try:
        r = run(['nix', 'eval', '--json', f'path:{flake}#{attr}'],
                capture_output=True, text=True)
    except FileNotFoundError:
        return None, 'nix is not installed'
    if r.returncode:
        lines = r.stderr.strip().splitlines()
        return None, lines[-1] if lines else f'nix eval exited {r.returncode}'
    return json.loads(r.stdout), None


def evaluated_categories(root, run=subprocess.run):
    """flake.categoryGraph -- {category: {dir, files, nested}} -- or (None, why)."""
    return evaluate(root, 'categoryGraph', run)


def static_categories(root):
    """The static parse in categoryGraph's shape, for comparing the two: each
    category's folder, the module files it collects itself (not those inside
    a nested category), and the categories nested in it. Files are every
    `.nix` the collector would take -- declaring a module or not."""
    root = pathlib.Path(root)
    scanned, _ = mod.scan(root)
    catdirs = {p.parent: name for name, p in scanned.items()}
    out = {}
    for name, shim in scanned.items():
        d = shim.parent
        files, nested = [], []
        for p in sorted(d.rglob('*')):
            if mod.hidden(p, root) or p == shim:
                continue
            inside = [a for a in p.parents if a in catdirs and d in a.parents]
            if p.is_dir() and p in catdirs and not inside:
                nested.append(p.name)
            elif p.is_file() and p.suffix == '.nix' and not inside and not mod.is_shim(p):
                files.append(p.relative_to(root).as_posix())
        out[name] = {'dir': d.relative_to(root).as_posix(), 'files': files,
                     'nested': sorted(nested)}
    return out


def compare_categories(static, evaluated):
    """Findings where the static parse and the collector disagree."""
    hits = []
    for name in sorted(set(static) | set(evaluated)):
        s, e = static.get(name), evaluated.get(name)
        if s is None:
            hits.append(f'VERIFY  category {name!r} ({e["dir"]}) is evaluated but the static '
                        f'parse finds no shim for it')
            continue
        if e is None:
            hits.append(f'VERIFY  category {name!r} ({s["dir"]}) is parsed but not in '
                        f'categoryGraph')
            continue
        if s['dir'] != e['dir']:
            hits.append(f'VERIFY  category {name!r}: parsed at {s["dir"]}, evaluated at {e["dir"]}')
        for f in sorted(set(s['files']) ^ set(e['files'])):
            side = 'parse' if f in s['files'] else 'collector'
            hits.append(f'VERIFY  category {name!r}: {f} is collected only per the {side}')
        for n in sorted(set(s['nested']) ^ set(e['nested'])):
            side = 'parse' if n in s['nested'] else 'collector'
            hits.append(f'VERIFY  category {name!r}: nested {n!r} only per the {side}')
    return hits


# --- --verify -------------------------------------------------------------

def verify(root, run=subprocess.run):
    """Parsed names against `nix eval .#modules.<class>`. Returns the findings.

    Every (class, filename) the parser found inside a category must be an
    evaluated attribute. Entry points outside every category name their
    aggregates by hand (`cubeConfiguration`), so they are not checked by
    filename and show up only as the informational other direction.

    First, membership: the static parse against flake.categoryGraph
    (compare_categories())."""
    root = pathlib.Path(root).resolve()
    hits = []
    evaluated, why = evaluated_categories(root, run)
    if evaluated is None:
        hits.append(f'VERIFY  nix eval of categoryGraph failed: {why}')
    else:
        hits += compare_categories(static_categories(root), evaluated)
    categories, by_name = mod.scan(root)
    catdirs = {p.parent for p in categories.values()}
    by_name = {n: [(p, c) for p, c in es if catdirs & set(p.parents)]
               for n, es in by_name.items()}
    for cls in CLASS_ORDER:
        names, why = evaluate(root, f'modules.{cls}', lambda cmd, **kw: run(
            cmd + ['--apply', 'builtins.attrNames'], **kw))
        if names is None:
            hits.append(f'VERIFY  nix eval of modules.{cls} failed: {why}')
            continue
        evaluated = set(names)
        parsed = {n for n, es in by_name.items() if any(cls in c for _, c in es)} | set(categories)
        hits += [f'VERIFY  {cls}.{n} is parsed from the tree but not an evaluated attribute'
                 for n in sorted(parsed - evaluated)]
        hits += [f'NOTE    {cls}.{n} is evaluated but not found by filename (an entry point '
                 f'naming its aggregate by hand)' for n in sorted(evaluated - parsed)]
    return hits


def main(argv=None, run=subprocess.run):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('cmd', choices=['tree', 'hosts', 'dot', 'html'])
    ap.add_argument('root', help='the flake/modules directory')
    ap.add_argument('--category')
    ap.add_argument('--depth', type=int)
    ap.add_argument('--categories-only', action='store_true')
    ap.add_argument('--view', choices=['tree', 'hosts'], default='tree',
                    help='for dot: which graph')
    ap.add_argument('--wrap', type=int, default=WRAP,
                    help=f'hosts view: categories per row in a shared area (default {WRAP}; 0: one row)')
    ap.add_argument('--static', action='store_true',
                    help='read categories from the files only; no nix eval')
    ap.add_argument('--verify', action='store_true')
    a = ap.parse_args(argv)
    view = a.view if a.cmd == 'dot' else 'hosts' if a.cmd == 'html' else a.cmd
    evaluated = None
    if not a.static:
        evaluated, why = evaluated_categories(a.root, run)
        if evaluated is None:
            print(f'note: categories from the static parse; nix eval of categoryGraph '
                  f'failed ({why})', file=sys.stderr)
    sub = select(graph(a.root, evaluated), view, a.category, a.depth, a.categories_only)
    if a.cmd == 'html':
        print(page(sub))
    else:
        print(dot(sub, a.wrap) if a.cmd == 'dot' else mermaid(sub, a.wrap))
    if a.verify:
        hits = verify(a.root, run)
        print('\n'.join(hits), file=sys.stderr)
        return 1 if any(h.startswith('VERIFY') for h in hits) else 0
    return 0


if __name__ == '__main__':
    sys.exit(main())
