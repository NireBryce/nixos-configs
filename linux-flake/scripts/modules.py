#!/usr/bin/env python3
"""Static analysis of the flake.modules tree.

    modules.py tree    <modules-dir> [--reverse]
    modules.py orphans <modules-dir>

In the dendritic layout a module opts *itself* into an aggregate, next to its
own definition:

    flake.modules.nixos.base.imports = [ config.flake.modules.nixos.bluetooth ];

which makes adding a module a one-file change, but means no file lists what an
aggregate contains. `tree` reconstructs that roster. `orphans` reports modules
nothing can reach, and is wired up as a flake check.

Parsing is textual, on the assumption every file follows the house style. It
segments each file at `flake.modules.<class>.<name>` declarations and treats
references found inside a segment as members of that declaration, which covers
both spellings in use:

    flake.modules.nixos.base.imports = [ config.flake.modules.nixos.bluetooth ];
    flake.modules.nixos.durandalConfiguration = {
        imports = with config.flake.modules.nixos; [ desktop durandalHardware ];
    };
"""
import re
import sys
import pathlib
from collections import defaultdict

DECL = re.compile(r"flake\.modules\.(\w+)\.([A-Za-z0-9_-]+)\s*(\.imports)?\s*=")
REF = re.compile(r"config\.flake\.modules\.(\w+)\.([A-Za-z0-9_-]+)")
WITH = re.compile(r"with\s+config\.flake\.modules\.(\w+)\s*;\s*\[(.*?)\]", re.S)
BARE = re.compile(r"^\s*([A-Za-z0-9_-]+)\s*$")


def refs_in(segment):
    """Every module a chunk of text refers to, in either spelling."""
    found = set(REF.findall(segment))
    for cls, body in WITH.findall(segment):
        for line in body.splitlines():
            m = BARE.match(line.split("#", 1)[0])
            if m:
                found.add((cls, m.group(1)))
    return found


def parse(path):
    """-> (declared, edges, referenced) for one file.

    `edges` is segment-scoped and precise, for display. `referenced` is every
    reference anywhere in the file, including any bound in a `let` before the
    first declaration -- enable-home-manager.nix does exactly that with
    ellyHomeManager, and a segment-scoped view loses the edge entirely.
    Reachability therefore uses the file-level view, which cannot lose edges.
    """
    text = path.read_text(encoding="utf-8", errors="replace")
    marks = [(m.start(), m.group(1), m.group(2)) for m in DECL.finditer(text)]

    declared, edges = set(), defaultdict(set)
    for i, (pos, cls, name) in enumerate(marks):
        end = marks[i + 1][0] if i + 1 < len(marks) else len(text)
        declared.add((cls, name))
        for r in refs_in(text[pos:end]):
            if r != (cls, name):
                edges[(cls, name)].add(r)

    return declared, edges, refs_in(text)


def collect(root):
    root = pathlib.Path(root)
    files = sorted(root.rglob("*.nix"))
    if not files:
        sys.exit(f"modules.py: no .nix files under {root}")

    declared_in = defaultdict(list)
    edges = defaultdict(set)
    file_refs, file_decls = {}, {}

    for f in files:
        d, e, r = parse(f)
        file_decls[f], file_refs[f] = d, r
        for key in d:
            declared_in[key].append(f)
        for k, v in e.items():
            edges[k] |= v

    return root, files, declared_in, edges, file_refs, file_decls


def cmd_tree(root_dir, reverse=False):
    root, files, declared_in, edges, _, _ = collect(root_dir)
    # An aggregate is anything that pulls in at least one other module.
    aggregates = {k for k, v in edges.items() if v}

    if reverse:
        member_of = defaultdict(set)
        for agg, members in edges.items():
            for m in members:
                member_of[m].add(agg)
        print("module -> the aggregates that include it\n")
        for cls, name in sorted(declared_in):
            if (cls, name) in aggregates and (cls, name) not in member_of:
                continue
            owners = sorted(f"{c}.{n}" for c, n in member_of.get((cls, name), []))
            print(f"  {cls}.{name}")
            print(f"      {', '.join(owners) if owners else '(nothing -- orphan)'}")
        return 0

    print("aggregate -> what it contains\n")
    for cls in sorted({c for c, _ in declared_in}):
        cls_aggs = sorted(n for c, n in aggregates if c == cls)
        if not cls_aggs:
            continue
        print(f"{cls}")
        for agg in cls_aggs:
            members = sorted(edges[(cls, agg)])
            sub = [n for c, n in members if (c, n) in aggregates]
            leaves = [n for c, n in members if (c, n) not in aggregates]
            header = f"  {agg}  ({len(members)})"
            if sub:
                header += f"   includes: {', '.join(sorted(sub))}"
            print(header)
            for name in leaves:
                where = declared_in.get((cls, name), [])
                loc = str(where[0].relative_to(root)) if where else "?? undeclared"
                print(f"      {name:<28} {loc}")
            print()
    return 0


def cmd_orphans(root_dir):
    root, files, declared_in, edges, file_refs, file_decls = collect(root_dir)

    # Files declaring nothing are entry points; hosts.nix is the real one,
    # since it names the host configs from flake.nixosConfigurations.
    roots = set()
    for f in files:
        if not file_decls[f]:
            roots |= file_refs[f]

    # File-level edges: every name a file declares reaches every name it
    # references. Conservative on purpose -- it can over-connect and hide a
    # real orphan, which beats a check that cries wolf and gets ignored.
    reach = defaultdict(set)
    for f in files:
        for key in file_decls[f]:
            reach[key] |= file_refs[f]

    reachable, queue = set(), [k for k in roots if k in declared_in]
    while queue:
        key = queue.pop()
        if key in reachable:
            continue
        reachable.add(key)
        for nxt in reach.get(key, ()):
            if nxt in declared_in and nxt not in reachable:
                queue.append(nxt)

    orphans = sorted(set(declared_in) - reachable)
    total = len(declared_in)
    if not orphans:
        print(f"modules.py: all {total} modules are reachable")
        return 0

    print(f"modules.py: {len(orphans)} of {total} modules are unreachable\n")
    for cls, name in orphans:
        where = ", ".join(str(p.relative_to(root)) for p in declared_in[(cls, name)])
        print(f"  flake.modules.{cls}.{name}")
        print(f"      declared in {where}")
    print(
        "\nNothing imports these, so they are dead. Either opt them into an"
        "\naggregate next to their definition, e.g."
        "\n    flake.modules.nixos.base.imports = [ config.flake.modules.nixos.NAME ];"
        "\nor delete them."
    )
    return 1


if __name__ == "__main__":
    args = sys.argv[1:]
    if len(args) < 2:
        sys.exit(__doc__)
    cmd, target, *rest = args
    if cmd == "tree":
        raise SystemExit(cmd_tree(target, reverse="--reverse" in rest))
    if cmd == "orphans":
        raise SystemExit(cmd_orphans(target))
    sys.exit(f"modules.py: unknown command '{cmd}'\n{__doc__}")
