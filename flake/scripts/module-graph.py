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
    module-graph.py hosts <modules-dir> [filters]   # host -> categories it imports, Mermaid
    module-graph.py dot   <modules-dir> [filters] [--view tree|hosts]   # Graphviz

Filters (a few hundred modules in one diagram is unreadable):

    --category NAME     only that category and what is nested in it; for `hosts`,
                        also only the hosts that import something in it
    --depth N           levels below the diagram's roots: areas (or the --category)
                        are level 0, their direct categories level 1
    --categories-only   leave the modules out

    --verify            also compare the parsed names with `nix eval .#modules.<class>`
                        attribute names; slow, and off by default

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
import argparse, json, pathlib, subprocess, sys
from dataclasses import dataclass

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import modules as mod  # noqa: E402

CLASS_LETTER = {'nixos': 'n', 'homeManager': 'h', 'darwin': 'd'}
CLASS_ORDER = list(CLASS_LETTER)


@dataclass(frozen=True)
class Node:
    id: str
    kind: str                # area | category | module | aggregate | missing
    label: str
    classes: frozenset = frozenset()
    count: int = 0           # category: modules beneath it, nested categories included
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
    imported = mod.imported_names(root)
    all_imported = set().union(*imported.values()) if imported else set()
    entries = sorted((p, n, c) for n, es in by_name.items() for p, c in es)

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
        """Nearest enclosing category, else the area directory."""
        for anc in path.parents:
            if anc in catdirs:
                return f'cat:{rel(anc)}'
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

    for path, name, classes in entries:
        nodes[f'mod:{rel(path)}'] = Node(f'mod:{rel(path)}', 'module', name,
                                         frozenset(classes), merges=merges(path, name, classes))

    # containment last, so area nodes are created in a stable order
    for nid, n in list(nodes.items()):
        if n.kind in ('category', 'module'):
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
    hide = {i for i in keep if g.nodes[i].kind == 'module' and (categories_only or view == 'hosts')}
    keep = [i for i in keep if i not in hide]
    if view == 'tree':
        shown = set(keep)
        edges = [e for e in g.edges if e.kind in ('contains', 'merges')
                 and e.src in shown and e.dst in shown]
        return Graph({i: g.nodes[i] for i in keep}, edges, [s for s in starts if s in shown])

    # hosts: every category in range, plus the aggregates that import into it
    shown = {i for i in keep if g.nodes[i].kind == 'category'}
    edges = [e for e in g.edges if e.kind == 'contains'
             and e.src in shown and e.dst in shown]
    for e in g.edges:
        if e.kind != 'imports' or e.dst not in g.nodes:
            continue
        if g.nodes[e.dst].kind == 'module':
            # a module imported by name (kde-desktop): drawn when its category is
            owner = next((c.src for c in g.edges if c.kind == 'contains' and c.dst == e.dst), None)
            if owner not in shown and category is not None:
                continue
            shown.add(e.dst)
            edges += [c for c in g.edges if c.kind == 'contains' and c.dst == e.dst
                      and c.src in shown and c not in edges]
            edges.append(e)
        elif e.dst in shown or (category is None and g.nodes[e.dst].kind == 'missing'):
            edges.append(e)
    used = {e.src for e in edges if e.kind == 'imports'}
    nodes = {i: n for i, n in g.nodes.items()
             if i in shown or (n.kind == 'aggregate' and i in used)
             or (n.kind == 'missing' and any(e.dst == i for e in edges))}
    # a module drawn only because a host names it hangs off its category
    for e in list(edges):
        if e.kind == 'contains' and e.src not in nodes:
            edges.remove(e)
    return Graph(nodes, edges, [])


# --- renderers ------------------------------------------------------------

def tag(n):
    """Node text: name, then classes (and module count for a category)."""
    if n.kind == 'category':
        return f'{n.label}/<br/>{" · ".join(x for x in (letters(n.classes), str(n.count)) if x)}'
    if n.kind == 'module' and n.classes:
        return f'{n.label}<br/>{letters(n.classes)}'
    if n.kind == 'missing':
        return f'{n.label}<br/>(no such module)'
    return n.label


def style(n):
    out = [n.kind]
    if n.kind == 'category' and n.status in ('orphan', 'by-module'):
        out.append(n.status.replace('-', ''))
    if n.merges:
        out.append('merges')
    return out


def esc(text):
    return text.replace('"', '#quot;')


def mermaid(g):
    ids = {i: f'n{k}' for k, i in enumerate(g.nodes)}
    lines = ['flowchart LR']
    for i, n in g.nodes.items():
        lines.append(f'    {ids[i]}["{esc(tag(n))}"]')
    for e in g.edges:
        a, b = ids[e.src], ids[e.dst]
        if e.kind == 'contains':
            nested = g.nodes[e.src].kind == g.nodes[e.dst].kind == 'category'
            lines.append(f'    {a} {"-.->" if nested else "-->"} {b}')
        elif e.kind == 'merges':
            lines.append(f'    {a} -. merges .- {b}')
        else:
            lines.append(f'    {a} -->|{CLASS_LETTER.get(e.cls, e.cls)}| {b}')
    members = {}
    for i, n in g.nodes.items():
        for s in style(n):
            members.setdefault(s, []).append(ids[i])
    lines += [
        '    classDef area fill:#eee,stroke:#888',
        '    classDef category fill:#dbeafe,stroke:#2563eb',
        '    classDef module fill:#fff,stroke:#555',
        '    classDef aggregate fill:#fef3c7,stroke:#b45309',
        '    classDef missing fill:#fee2e2,stroke:#b91c1c',
        '    classDef orphan fill:#fff,stroke:#dc2626,stroke-width:3px,color:#b91c1c',
        '    classDef bymodule stroke-dasharray:5 3',
        '    classDef merges stroke:#dc2626,stroke-width:3px',
    ]
    lines += [f'    class {",".join(v)} {k}' for k, v in members.items()]
    return '\n'.join(lines)


def dot(g):
    shape = {'area': 'folder', 'category': 'box', 'module': 'ellipse',
             'aggregate': 'component', 'missing': 'octagon'}
    ids = {i: f'n{k}' for k, i in enumerate(g.nodes)}
    lines = ['digraph modules {', '    rankdir=LR;', '    node [fontname="sans-serif"];']
    for i, n in g.nodes.items():
        attrs = [f'label="{esc(tag(n).replace("<br/>", chr(92) + "n"))}"', f'shape={shape[n.kind]}']
        if 'orphan' in style(n):
            attrs.append('color=red penwidth=3 fontcolor=red')
        if 'bymodule' in style(n):
            attrs.append('style=dashed')
        if n.merges:
            attrs.append('color=red penwidth=3')
        lines.append(f'    {ids[i]} [{" ".join(attrs)}];')
    for e in g.edges:
        a, b = ids[e.src], ids[e.dst]
        if e.kind == 'contains':
            nested = g.nodes[e.src].kind == g.nodes[e.dst].kind == 'category'
            lines.append(f'    {a} -> {b}' + (' [style=dotted];' if nested else ';'))
        elif e.kind == 'merges':
            lines.append(f'    {a} -> {b} [label="merges" color=red style=dashed dir=none];')
        else:
            lines.append(f'    {a} -> {b} [label="{CLASS_LETTER.get(e.cls, e.cls)}"];')
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
