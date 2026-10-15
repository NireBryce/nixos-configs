#!/usr/bin/env python3
"""Draws the module tree: which categories exist, what sits in them, and which
host imports what -- the picture behind `modules.py`'s checks.

Everything is read statically from the files (modules.py's parsing, not a
second parser), so it runs on darwin too and needs no `nix eval`. A module
belongs to the category of the directory it sits in, a host imports categories
by name, and neither fact is written down anywhere as a list; this is that list.

The model is one function, `graph(root)`, returning plain nodes and edges.
`select()` narrows it, and the three subcommands are thin renderers:

    module-graph.py tree  <modules-dir> [filters]   # category -> module tree, Mermaid
    module-graph.py hosts <modules-dir> [filters]   # host -> categories it imports, Mermaid;
                                                    # top-down, each host's own host-config/
                                                    # category above it, shared ones below
    module-graph.py dot   <modules-dir> [filters] [--view tree|hosts]   # Graphviz

Filters (a few hundred modules in one diagram is unreadable):

    --category NAME     only that category and what is nested in it; for `hosts`,
                        also only the hosts that import something in it
    --depth N           directory levels below the diagram's roots: areas (or the
                        --category) are level 0, what sits directly in them level 1
    --categories-only   leave out modules and the plain folders holding them

    --verify            also compare the parsed names with `nix eval .#modules.<class>`
                        attribute names; slow, and off by default

Colour standard (PALETTE below holds it). Importable categories -- a
directory holding a dirsAsCategory.nix, which a host can name -- are blue
rounded cards, reached by dotted edges. Implicit folders -- plain
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
import argparse, html, json, pathlib, subprocess, sys
from dataclasses import dataclass

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import modules as mod  # noqa: E402

CLASS_LETTER = {'nixos': 'n', 'homeManager': 'h', 'darwin': 'd'}
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
    kind: str                # contains | imports | merges
    cls: str = ''            # imports: the class of the aggregate that lists it


@dataclass
class Graph:
    nodes: dict              # id -> Node, in insertion order
    edges: list
    roots: list              # ids the `contains` tree hangs from


def letters(classes):
    known = [CLASS_LETTER[c] for c in CLASS_ORDER if c in classes]
    return ' '.join(known + sorted(c for c in classes if c not in CLASS_LETTER))


def graph(root):
    root = pathlib.Path(root)
    categories, by_name = mod.scan(root)
    catdirs = {p.parent: name for name, p in categories.items()}
    # A plain directory inside a category: no shim, so no host can name it --
    # its modules arrive only through the category above it (the collector's
    # walkSubdir). Drawn as its own node so the two kinds of directory can be
    # told apart; `_` paths are already out of `entries`.
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
        return name in categories or bool(same)

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
        if name in categories:
            edges.append(Edge(f'mod:{rel(path)}', f'cat:{rel(categories[name].parent)}', 'merges'))
        for p2, c2 in by_name[name]:
            if p2 > path and c2 & classes:
                edges.append(Edge(f'mod:{rel(path)}', f'mod:{rel(p2)}', 'merges'))

    for path, cls, listed in mod.aggregates(root):
        aid = f'agg:{rel(path)}:{cls}'
        nodes.setdefault(aid, Node(aid, 'aggregate', path.stem, frozenset([cls])))
        for name in dict.fromkeys(listed):
            if name in categories:
                targets = [f'cat:{rel(categories[name].parent)}']
            elif name in by_name:
                targets = [f'mod:{rel(p)}' for p, c in by_name[name]]
            else:
                targets = [f'missing:{name}']
                nodes.setdefault(targets[0], Node(targets[0], 'missing', name))
            edges += [Edge(aid, t, 'imports', cls) for t in targets]
    return Graph(nodes, edges, roots)


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
    return Graph(nodes, containment(list(nodes), shown) + imports, [])


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


def groups(g):
    """[(id, title, members)]: the containers a diagram draws. Areas in the
    tree view (their `contains` edges are the containment, not arrows); the
    host and home entry points together in the hosts view. An area holds
    everything beneath it, so a nested category sits in its area's box."""
    kids = {}
    for e in g.edges:
        if e.kind == 'contains':
            kids.setdefault(e.src, []).append(e.dst)
    out = []
    for i, n in g.nodes.items():
        if n.kind != 'area':
            continue
        members, queue = [], list(kids.get(i, []))
        while queue:
            m = queue.pop(0)
            if m in g.nodes and m not in members:
                members.append(m)
                queue += kids.get(m, [])
        out.append((i, n.label, members))
    entry = [i for i, n in g.nodes.items() if n.kind == 'aggregate']
    if entry:
        out.append(('grp:entry', 'hosts and home', entry))
    return out


def arrows(g):
    """The edges drawn as arrows: everything but an area's containment."""
    return [e for e in g.edges
            if not (e.kind == 'contains' and g.nodes[e.src].kind == 'area')]


# The hosts view runs top-down, imports flowing down from the hosts --
# except into a host's own directory under host-config/ (hosts.nix's
# convention: host-config/<host>/ is a category only that host imports),
# which is drawn ABOVE the hosts: it is the host's own definition, not
# something it pulls in from the shared tree.
HOST_AREA = 'host-config'


def hosts_view(g):
    return any(n.kind == 'aggregate' for n in g.nodes.values())


def upward(g, e):
    """An import into a category under HOST_AREA: drawn pointing up."""
    return (e.kind == 'imports' and g.nodes[e.dst].kind == 'category'
            and e.dst.split(':', 1)[1].split('/')[0] == HOST_AREA)


def esc(text):
    return text.replace('"', '#quot;')


MERMAID_INIT = ('%%{init: {"theme": "base", "themeVariables": {"fontFamily": '
                '"ui-sans-serif, system-ui, sans-serif", "fontSize": "14px", '
                f'"lineColor": "{LINE}"}}, "flowchart": {{"curve": "basis", '
                '"nodeSpacing": 24, "rankSpacing": 80, "padding": 14}}}%%')


def mermaid(g):
    ids = {i: f'n{k}' for k, i in enumerate(g.nodes)}
    shape = {'category': '({})', 'folder': '[{}]', 'module': '([{}])', 'aggregate': '[[{}]]',
             'missing': '{{{{{}}}}}', 'area': '[{}]'}

    def card(i):
        n = g.nodes[i]
        title, sub = parts(n)
        text = f'<b>{title}</b>' + (f'<br/><i>{sub}</i>' if sub else '')
        return f'{ids[i]}{shape[n.kind].format(chr(34) + esc(text) + chr(34))}'

    lines = [MERMAID_INIT, f'flowchart {"TB" if hosts_view(g) else "LR"}']
    boxed, hue = set(), hues(g)
    drawn = arrows(g)
    # Mermaid stacks unconnected containers bottom-up; reversed, the areas
    # read top-down in the order the tree lists them.
    for k, (gid, title, members) in (list(enumerate(groups(g)))[::-1] if not drawn
                                     else enumerate(groups(g))):
        members = [m for m in members if m in g.nodes]
        if not members:
            continue
        lines.append(f'    subgraph g{k}["{esc(title)}"]')
        lines += [f'        {card(m)}' for m in members]
        lines.append('    end')
        boxed.update(members)
        if gid in g.nodes:
            boxed.add(gid)
        fill, line = PALETTE['area'] if gid in g.nodes else ('#fefce8', '#fde68a')
        lines.append(f'    style g{k} fill:{fill},stroke:{line},color:{QUIET}')
    lines += [f'    {card(i)}' for i in g.nodes if i not in boxed and g.nodes[i].kind != 'area']
    # Mermaid has no reversed arrow, and ranks by edge direction; an upward
    # import is an invisible `category ~~~ host` link (which ranks the
    # category above) plus the real arrow. linkStyle indexes count the
    # invisible links too, hence the explicit counter.
    by_hue, k = {}, -1
    for e in drawn:
        k += 1
        a, b = ids[e.src], ids[e.dst]
        if upward(g, e):
            lines.append(f'    {b} ~~~ {a}')
            k += 1
        if e.kind == 'contains':
            # into a category: dotted, since it is importable on its own too
            nested = g.nodes[e.dst].kind == 'category'
            lines.append(f'    {a} {"-.->" if nested else "-->"} {b}')
        elif e.kind == 'merges':
            lines.append(f'    {a} -. merges .- {b}')
        else:
            lines.append(f'    {a} --> {b}')
            by_hue.setdefault(hue[e.src], []).append(str(k))
    lines += [f'    linkStyle {",".join(v)} stroke:{h},stroke-width:1.5px'
              for h, v in by_hue.items()]
    lines += [f'    style {ids[a]} stroke:{h},stroke-width:2px' for a, h in hue.items()]
    for kind in PALETTE:
        fill, line = PALETTE[kind]
        lines.append(f'    classDef {kind} fill:{fill},stroke:{line},color:{INK},stroke-width:1.5px')
    lines += [f'    classDef orphan fill:{ALERT[0]},stroke:{ALERT[1]},color:{INK},stroke-width:2.5px',
              f'    classDef bymodule stroke-dasharray:5 3',
              f'    classDef merges stroke:{ALERT[1]},stroke-width:2.5px']
    members = {}
    for i, n in g.nodes.items():
        if n.kind == 'area':
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


def dot(g):
    ids = {i: f'n{k}' for k, i in enumerate(g.nodes)}

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

    hue, drawn = hues(g), arrows(g)
    # With no arrows (areas and their categories only) a left-to-right layout
    # stacks every card in one column; top-down plus invisible edges every
    # GRID cards lays each area out as a grid instead.
    # The hosts view runs top-down (HOST_AREA above the hosts, see upward()).
    lines = ['digraph modules {',
             f'    rankdir={"LR" if drawn and not hosts_view(g) else "TB"}; bgcolor="white"; nodesep=0.22; '
             f'ranksep={0.9 if drawn else 0.3}; splines=true; newrank=true;',
             f'    node [shape=box style="rounded,filled" fontname="Helvetica" fontsize=11 '
             f'fontcolor="{INK}" penwidth=1.3 margin="0.16,0.08"];',
             f'    edge [color="{LINE}" fontname="Helvetica" fontsize=9 fontcolor="{QUIET}" '
             f'arrowsize=0.7];']
    boxed = set()
    for k, (gid, title, members) in enumerate(groups(g)):
        members = [m for m in members if m in g.nodes]
        if not members:
            continue
        fill, line = PALETTE['area'] if gid in g.nodes else ('#fefce8', '#fde68a')
        lines += [f'    subgraph cluster_{k} {{',
                  f'        label=<<font color="{QUIET}" point-size="10">{html.escape(title)}</font>>;',
                  f'        style="rounded,filled"; fillcolor="{fill}"; color="{line}"; margin=14;']
        lines += [f'        {card(m)}' for m in members]
        if not drawn:
            lines += [f'        {ids[a]} -> {ids[b]} [style=invis];'
                      for a, b in zip(members, members[GRID:])]
        lines.append('    }')
        boxed.update(members)
    lines += [f'    {card(i)}' for i in g.nodes if i not in boxed and g.nodes[i].kind != 'area']
    if hosts_view(g):
        # A shared category nothing imports whole (desktop-env, an orphan)
        # has no edge to rank it, lands on the hosts' row, and drags its
        # whole area up beside them. Pinned below the hosts, invisibly.
        first = next(i for i, n in g.nodes.items() if n.kind == 'aggregate')
        incoming = {e.dst for e in drawn}
        lines += [f'    {ids[first]} -> {ids[i]} [style=invis];' for i, n in g.nodes.items()
                  if n.kind == 'category' and i not in incoming
                  and i.split(':', 1)[1].split('/')[0] != HOST_AREA]
    for e in drawn:
        a, b = ids[e.src], ids[e.dst]
        if e.kind == 'contains':
            nested = g.nodes[e.dst].kind == 'category'
            lines.append(f'    {a} -> {b}' + (' [style=dotted];' if nested else ';'))
        elif e.kind == 'merges':
            lines.append(f'    {a} -> {b} [label="merges" color="{ALERT[1]}" fontcolor="{ALERT[1]}" '
                         f'style=dashed dir=none];')
        elif upward(g, e):
            # reversed for ranking, arrowhead kept on the category
            lines.append(f'    {b} -> {a} [dir=back color="{hue[e.src]}" penwidth=1.2];')
        else:
            lines.append(f'    {a} -> {b} [color="{hue[e.src]}" penwidth=1.2];')
    lines.append('}')
    return '\n'.join(lines)


# --- --verify -------------------------------------------------------------

def verify(root):
    """Parsed names against `nix eval .#modules.<class>`. Returns the findings.

    Every (class, filename) the parser found inside a category must be an
    evaluated attribute. Entry points outside every category name their
    aggregates by hand (`cubeConfiguration`), so they are not checked by
    filename and show up only as the informational other direction."""
    root = pathlib.Path(root).resolve()
    flake = root.parent
    categories, by_name = mod.scan(root)
    catdirs = {p.parent for p in categories.values()}
    by_name = {n: [(p, c) for p, c in es if catdirs & set(p.parents)]
               for n, es in by_name.items()}
    hits = []
    for cls in CLASS_ORDER:
        r = subprocess.run(['nix', 'eval', '--json', f'path:{flake}#modules.{cls}',
                            '--apply', 'builtins.attrNames'], capture_output=True, text=True)
        if r.returncode:
            hits.append(f'VERIFY  nix eval of modules.{cls} failed: {r.stderr.strip().splitlines()[-1]}')
            continue
        evaluated = set(json.loads(r.stdout))
        parsed = {n for n, es in by_name.items() if any(cls in c for _, c in es)} | set(categories)
        hits += [f'VERIFY  {cls}.{n} is parsed from the tree but not an evaluated attribute'
                 for n in sorted(parsed - evaluated)]
        hits += [f'NOTE    {cls}.{n} is evaluated but not found by filename (an entry point '
                 f'naming its aggregate by hand)' for n in sorted(evaluated - parsed)]
    return hits


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('cmd', choices=['tree', 'hosts', 'dot'])
    ap.add_argument('root', help='the flake/modules directory')
    ap.add_argument('--category')
    ap.add_argument('--depth', type=int)
    ap.add_argument('--categories-only', action='store_true')
    ap.add_argument('--view', choices=['tree', 'hosts'], default='tree',
                    help='for dot: which graph')
    ap.add_argument('--verify', action='store_true')
    a = ap.parse_args(argv)
    view = a.view if a.cmd == 'dot' else a.cmd
    sub = select(graph(a.root), view, a.category, a.depth, a.categories_only)
    print(dot(sub) if a.cmd == 'dot' else mermaid(sub))
    if a.verify:
        hits = verify(a.root)
        print('\n'.join(hits), file=sys.stderr)
        return 1 if any(h.startswith('VERIFY') for h in hits) else 0
    return 0


if __name__ == '__main__':
    sys.exit(main())
