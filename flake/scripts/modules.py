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
# `config.flake.modules.<class>.<name>` -- one module importing another directly,
# rather than a host aggregate listing it. Bound in a `let` above the body, since
# inside it `config` is the NixOS/HM one; enable-home-manager.nix reaches
# ellyHomeManager this way and kde-desktop.nix/jovian.nix both reach kde-base.
#
# The name is [\w-]+, not \w+: hyphens are legal in Nix identifiers, so `kde-base`
# is one attribute and not a subtraction. Matching \w+ here would silently record
# a reference to `kde` and leave kde-base looking like an orphan.
REF = re.compile(r'config\.flake\.modules\.(\w+)\.([\w-]+)')
COMMENT = re.compile(r'#[^\n]*')


def scan(root):
    """categories: name -> dirsAsCategory path.  modules: name -> [(path, classes)].

    modules maps to a *list*, not a single entry. Keying it by stem and assigning
    would silently drop one of two same-named files, which is the exact case
    `collisions` exists to report -- the checker would have overwritten the
    evidence and then found nothing.
    """
    root = pathlib.Path(root)
    categories, modules = {}, {}
    for p in sorted(root.rglob('*.nix')):
        if p.name == CATEGORY_FILE:
            categories[p.parent.name] = p
            continue
        classes = {m.group(1) for m in DECL.finditer(p.read_text())}
        if classes:
            modules.setdefault(p.stem, []).append((p, classes))
    return categories, modules


def imported_names(root):
    """Names anything imports, by class.

    Two forms count. Aggregates list members with `with config.flake.modules.
    <class>; [ ... ]`; they live directly under a namespace dir (nireHost/,
    nireUser/), where dirsAsCategory cannot collect them -- which is also what
    makes them findable as 'not in a category dir'.

    A module can also import another module directly, by naming it as
    `config.flake.modules.<class>.<name>`. That form is not a host's choice and
    can appear anywhere, including inside a category.
    """
    out = {}
    for p in pathlib.Path(root).rglob('*.nix'):
        if p.name == CATEGORY_FILE:
            continue
        text = p.read_text()
        for m in AGG.finditer(text):
            cls, body = m.group(1), m.group(2)
            body = COMMENT.sub('', body)                 # strip trailing comments
            out.setdefault(cls, set()).update(re.findall(r'[\w-]+', body))
        # Comments are stripped first here: several modules discuss
        # `config.flake.modules` in prose, and a reference named only in a
        # comment would mark a genuinely dead module as reachable.
        for m in REF.finditer(COMMENT.sub('', text)):
            out.setdefault(m.group(1), set()).add(m.group(2))
    return out


def collisions(root):
    """Two ways one attribute ends up with two owners, both silent."""
    categories, modules = scan(root)
    hits = []

    # a module named the same as a category
    for n in sorted(set(categories) & set(modules)):
        for path, _ in modules[n]:
            print(f"COLLISION  {n!r}: category {categories[n].parent}/ and module "
                  f"{path} declare the same attribute; they merge")
        hits.append(n)

    # two modules with the same filename, anywhere in the tree. Only collides
    # per class, so `foo.nix` declaring nixos and another declaring homeManager
    # is legal -- reported only when the classes actually overlap.
    for n, entries in sorted(modules.items()):
        if len(entries) < 2:
            continue
        for i, (p1, c1) in enumerate(entries):
            for p2, c2 in entries[i + 1:]:
                shared = c1 & c2
                if shared:
                    print(f"COLLISION  {n!r}: {p1} and {p2} both declare "
                          f"{'/'.join(sorted(shared))}.{n}; they merge")
                    hits.append(n)
    return hits


def orphans(root):
    """Reachability is per module, not per category.

    collectModules recurses, so a module in a nested category is also collected
    by every category above it -- `rust` sits in `langs`, but `development`
    picks it up too. Checking categories directly would report every nested one
    as dead. So: walk each module's ancestors, and treat it as reachable if the
    module itself is imported by name (durandal takes `kde-desktop` that way,
    and kde-desktop in turn takes `kde-base`) or any ancestor category is.
    """
    categories, modules = scan(root)
    imported = imported_names(root)
    all_imported = set().union(*imported.values()) if imported else set()
    catdirs = {p.parent: name for name, p in categories.items()}

    findings = []
    for name, (path, classes) in sorted(
        (n, e) for n, entries in modules.items() for e in entries
    ):
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
