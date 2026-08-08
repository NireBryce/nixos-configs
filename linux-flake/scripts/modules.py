#!/usr/bin/env python3
"""Static checks over the module tree, for the things evaluation cannot report.

Membership here is implicit: a module belongs to the category of the directory it
sits in, and a host imports categories by name. Two failures follow from that,
and neither produces an error -- the tree evaluates perfectly happily with either.

  collisions  A module whose filename equals a category name declares into the
              same attribute as that category, and same-named modules MERGE
              rather than conflicting. This is how `boot` came to mean both
              nire/boot/ (which wipes /root on boot) and durandal's bootloader.

  orphans     A module in a category that no host or home aggregate imports is
              valid, evaluates, and installs nothing.

Both are platform independent, so unlike the host checks they also run on darwin.

    modules.py collisions <modules-dir>
    modules.py orphans    <modules-dir>
    modules.py check      <modules-dir>     # both; non-zero exit on any finding
"""
import re, sys, pathlib

CATEGORY_FILE = 'dirsAsCategory.nix'
DECL = re.compile(r'flake\.modules\.(\w+)\.(?:\$\{moduleName\}|(\w+))')
# `with config.flake.modules.<class>; [ a b c ]` -- how the aggregates list members
AGG = re.compile(r'with\s+config\.flake\.modules\.(\w+);\s*\[(.*?)\]', re.S)


def scan(root):
    root = pathlib.Path(root)
    categories, modules = {}, {}
    for p in sorted(root.rglob('*.nix')):
        if p.name == CATEGORY_FILE:
            categories[p.parent.name] = p
            continue
        classes = {m.group(1) for m in DECL.finditer(p.read_text())}
        if classes:
            modules[p.stem] = (p, classes)
    return categories, modules


def imported_names(root):
    """Names any aggregate imports, by class. Aggregates live directly under a
    namespace dir (nireHost/, nireUser/), where dirsAsCategory cannot collect
    them -- which is also what makes them findable as 'not in a category dir'."""
    out = {}
    for p in pathlib.Path(root).rglob('*.nix'):
        if p.name == CATEGORY_FILE:
            continue
        for m in AGG.finditer(p.read_text()):
            cls, body = m.group(1), m.group(2)
            body = re.sub(r'#[^\n]*', '', body)          # strip trailing comments
            out.setdefault(cls, set()).update(re.findall(r'[\w-]+', body))
    return out


def collisions(root):
    categories, modules = scan(root)
    hits = sorted(set(categories) & set(modules))
    for n in hits:
        print(f"COLLISION  {n!r}: category {categories[n].parent}/ "
              f"and module {modules[n][0]} declare the same attribute; they merge")
    return hits


def orphans(root):
    """Reachability is per module, not per category.

    collectModules recurses, so a module in a nested category is also collected
    by every category above it -- `rust` sits in `langs`, but `development`
    picks it up too. Checking categories directly would report every nested one
    as dead. So: walk each module's ancestors, and treat it as reachable if the
    module itself is imported by name (durandal takes `kde` that way) or any
    ancestor category is.
    """
    categories, modules = scan(root)
    imported = imported_names(root)
    all_imported = set().union(*imported.values()) if imported else set()
    catdirs = {p.parent: name for name, p in categories.items()}

    findings = []
    for name, (path, classes) in sorted(modules.items()):
        if name in all_imported:
            continue

        if 'ORPHAN-OK' in path.read_text():
            # Deliberately unreachable, and says so in the file. Used for modules
            # kept for a host that is not currently configured.
            continue

        ancestors = [d for d in path.parents if d in catdirs]
        if not ancestors:
            # Outside every category tree. That is how entry points are defined
            # here -- hosts.nix, durandal-configuration.nix, elly-home-manager.nix
            # and checks.nix all sit where dirsAsCategory cannot reach them, on
            # purpose. Nothing is meant to import them.
            continue

        # A category collects from its *sub*directories only, so a file sitting
        # directly in the category dir is not collected by it. Excluding the
        # immediate parent is what catches that.
        reaching = [catdirs[d] for d in ancestors if d != path.parent]
        if not any(c in all_imported for c in reaching):
            findings.append((name, path, reaching))

    for name, path, reaching in findings:
        via = (' / '.join(reaching) if reaching
               else 'none -- it sits directly in a category dir, which collects '
                    'only from subdirectories')
        print(f"ORPHAN     {name!r} ({path}) is imported by nothing; "
              f"reachable via: {via}")
    return findings


def main():
    if len(sys.argv) != 3:
        print(__doc__); sys.exit(2)
    cmd, root = sys.argv[1], sys.argv[2]
    if cmd == 'collisions':
        sys.exit(1 if collisions(root) else 0)
    if cmd == 'orphans':
        sys.exit(1 if orphans(root) else 0)
    if cmd == 'check':
        bad = bool(collisions(root)) | bool(orphans(root))
        print("no findings" if not bad else "", end="")
        sys.exit(1 if bad else 0)
    print(__doc__); sys.exit(2)


main()
