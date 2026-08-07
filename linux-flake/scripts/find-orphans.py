#!/usr/bin/env python3
"""Find flake.modules entries that nothing can reach.

In the dendritic layout a module opts *itself* into an aggregate, so forgetting
that one line leaves a module that is perfectly valid, evaluates fine, and is
simply never used. `nix flake check` cannot notice: from its point of view
nothing is wrong. This is a static reachability check over the module tree.

    find-orphans.py <modules-dir>

Exits 1 if anything is unreachable, printing what and where.

Model: each file declares zero or more module names and references zero or
more. A file that declares nothing is an entry point -- hosts.nix is the real
one, since it names the host configs from flake.nixosConfigurations -- so the
names it references are roots. From there, reaching a name reaches everything
referenced by the file(s) declaring it.

Deliberately conservative. Every name a file references is treated as reachable
from every name that file declares, which can over-connect and hide a genuine
orphan. That is the right way round: a check with false positives gets ignored.
"""
import re
import sys
import pathlib
from collections import defaultdict

DECL = re.compile(r"flake\.modules\.(\w+)\.([A-Za-z0-9_-]+)\s*(?:=|\.imports)")
REF = re.compile(r"config\.flake\.modules\.(\w+)\.([A-Za-z0-9_-]+)")
WITH = re.compile(r"with\s+config\.flake\.modules\.(\w+)\s*;\s*\[(.*?)\]", re.S)
BARE = re.compile(r"^\s*([A-Za-z0-9_-]+)\s*$")


def parse(path):
    """Return (declared, referenced) as sets of (class, name)."""
    text = path.read_text(encoding="utf-8", errors="replace")
    declared = set(DECL.findall(text))
    declared = {(c, n) for c, n, *_ in [(c, n) for c, n in declared]}
    referenced = set(REF.findall(text))

    # `with config.flake.modules.nixos; [ a b c ]` -- bare names, and the list
    # carries trailing comments, so strip those before matching.
    for cls, body in WITH.findall(text):
        for line in body.splitlines():
            line = line.split("#", 1)[0]
            m = BARE.match(line)
            if m:
                referenced.add((cls, m.group(1)))
    return declared, referenced


def main(root):
    root = pathlib.Path(root)
    files = sorted(root.rglob("*.nix"))
    if not files:
        print(f"find-orphans: no .nix files under {root}", file=sys.stderr)
        return 2

    declares = {}          # file -> set of (class, name)
    references = {}        # file -> set of (class, name)
    declared_in = defaultdict(list)   # (class, name) -> [file, ...]

    for f in files:
        d, r = parse(f)
        declares[f], references[f] = d, r
        for key in d:
            declared_in[key].append(f)

    # Entry points: files that declare nothing but reference something.
    roots = set()
    for f in files:
        if not declares[f]:
            roots |= references[f]

    reachable = set()
    queue = [k for k in roots if k in declared_in]
    while queue:
        key = queue.pop()
        if key in reachable:
            continue
        reachable.add(key)
        for f in declared_in[key]:
            for nxt in references[f]:
                if nxt in declared_in and nxt not in reachable:
                    queue.append(nxt)

    orphans = sorted(set(declared_in) - reachable)
    total = len(declared_in)

    if not orphans:
        print(f"find-orphans: all {total} modules are reachable")
        return 0

    print(f"find-orphans: {len(orphans)} of {total} modules are unreachable\n")
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
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        raise SystemExit(2)
    raise SystemExit(main(sys.argv[1]))
