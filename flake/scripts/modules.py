#!/usr/bin/env python3
"""Static checks over the module tree, for the things evaluation cannot report.

Membership here is implicit: a module belongs to the category of the directory it
sits in, and a host imports categories by name. Two failures follow from that,
and neither produces an error -- the tree evaluates perfectly happily with either.

  collisions  A module whose filename equals a category name declares into the
              same attribute as that category, and same-named modules MERGE
              rather than conflicting. This is how `boot` came to mean both
              config-system/boot/ (which wipes /root on boot) and durandal's bootloader.

  orphans     A module in a category that no host or home aggregate imports is
              valid, evaluates, and installs nothing.

Both are platform independent, so unlike the host checks they also run on darwin.

    modules.py collisions <modules-dir>
    modules.py orphans    <modules-dir>
    modules.py untracked  <modules-dir>     # untracked .nix files -- invisible to flakes
    modules.py check      <modules-dir>     # all three; non-zero exit on any finding

    modules.py add <modules-dir> <class> <category>/<subdir>/<name>.nix [description words...]
                           # scaffold a new module where the collector will
                           # actually find it, with boilerplate per
                           # wiki/module-style-guide.md; `git add`s the file
                           # (flakes ignore untracked ones) and runs the
                           # checks above immediately. The new module is
                           # reported as an ORPHAN on purpose -- nothing
                           # imports it yet.
"""
import re, sys, pathlib, subprocess

CATEGORY_FILE = 'dirsAsCategory.nix'
DECL = re.compile(r'flake\.modules\.(\w+)\.(?:\$\{moduleName\}|(\w+))')
# Declared inside a `flake.modules = { ... }` attrset, where each class
# heads its own line without the prefix. Line-anchored so the leading
# `flake` of a flat `flake.modules.<class>...` line cannot match as a
# class name. basic-nix-settings.nix is the one module shaped this way;
# missed by this and check_wiki.py's CLASSES scan until 2026-09-08.
DECL_ATTRSET = re.compile(r'(?m)^\s*(\w+)\.\$\{moduleName\}\s*=')
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
        classes.update(DECL_ATTRSET.findall(p.read_text()))
        if classes:
            modules.setdefault(p.stem, []).append((p, classes))
    return categories, modules


def imported_names(root):
    """Names anything imports, by class.

    Two forms count. Aggregates list members with `with config.flake.modules.
    <class>; [ ... ]`; they live directly under a namespace dir (hosts/,
    users/), where dirsAsCategory cannot collect them -- which is also what
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


def untracked(root):
    """A new .nix file that git doesn't know about yet.

    CLAUDE.md, 'Working in this repo': flakes in a git repo ignore untracked
    files, so a brand-new module silently does not exist as far as `nix eval`
    or a build is concerned -- no error, just a module that was never there.
    `git status` already reports this, but nothing surfaces it at the moment
    it actually matters (right before a check/build), so it stays easy to
    forget in exactly the way that trap already bit once.
    """
    try:
        out = subprocess.run(
            ['git', 'status', '--porcelain', '--untracked-files=all', '--', str(root)],
            capture_output=True, text=True, check=True,
        ).stdout
    except (subprocess.CalledProcessError, FileNotFoundError):
        return []           # not a git checkout, or git unavailable -- nothing to report
    hits = [line[3:] for line in out.splitlines()
            if line.startswith('??') and line[3:].endswith('.nix')]
    for path in hits:
        print(f"UNTRACKED  {path} -- `git add` it, or nix will silently act as "
              f"though it does not exist")
    return hits


# The classes that mean anything (new-flake-module skill): flake-parts stamps
# whatever class is declared straight into `_class` and validates nothing, so
# a typo here declares fine and fails much later, at the import site. `darwin`
# works only because nix-darwin sets that `_class` itself.
CLASSES = ('nixos', 'homeManager', 'flake', 'generic', 'darwin')

# wiki/module-style-guide.md's module header: name derived from the filename
# (never hardcoded), opening brackets on the same line, four-space indent, and
# the `# # description` comment as the first line of the body. The inner
# lambda is `_:` rather than `{ ... }:` -- statix flags the empty pattern and
# a fresh file would raise the lint ratchet; whoever fleshes the module out
# will destructure `config`/`pkgs` anyway. No history heading: that is added
# when there is something historical to record, not at birth.
#
# Tokens, not str.format: the text is full of literal Nix braces, and every
# one of them is a format field waiting to KeyError.
BOILERPLATE = '''{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.@CLASS@.${moduleName} = _: {
            # # description = "@DESC@";
        };
}
'''


def add(root, cls, target, description):
    """Scaffold a module file where the collector will actually find it.

    Every rule enforced here is one that has silently bitten (the
    new-flake-module skill collects them): the declared name comes from the
    filename, never hardcoded; the target must sit in a subdirectory of a
    category, because a category collects from its subdirectories only and a
    file directly in the category dir is collected by nothing; the class must
    be one that means something; and a name that already exists is refused or
    warned about, because same-named declarations merge instead of
    conflicting. The file is `git add`-ed -- flakes in a git repo ignore
    untracked files -- and the checks run immediately, so a mistake is caught
    this second rather than at the next build.
    """
    if cls not in CLASSES:
        print(f"error: class {cls!r} is not one that means anything here "
              f"({', '.join(CLASSES)}); a wrong class declares fine and "
              f"fails only at the import site", file=sys.stderr)
        return 1
    target = pathlib.Path(target)
    if target.is_absolute() or '..' in target.parts:
        print(f"error: target must be a relative path under {root}",
              file=sys.stderr)
        return 1
    if target.suffix != '.nix' or len(target.parts) < 2:
        print("error: target must name a .nix file inside a subdirectory of "
              "a category, e.g. "
              "config-system/system/my-thing/my-thing.nix", file=sys.stderr)
        return 1
    description = ' '.join(description) if description else "TODO: one line"
    if '"' in description or '${' in description:
        # Either would break the "..." string in the generated Nix: a quote
        # terminates it, `${` interpolates.
        print('error: description must not contain `"` or `${`',
              file=sys.stderr)
        return 1

    root = pathlib.Path(root)
    path = root / target
    if path.exists():
        print(f"error: {path} already exists", file=sys.stderr)
        return 1

    categories, modules = scan(root)
    catdirs = {p.parent: name for name, p in categories.items()}

    category = next((catdirs[anc] for anc in path.parents if anc in catdirs),
                    None)
    if category is None:
        print(f"error: {target} sits outside every category tree; a module "
              f"must be under a directory holding a dirsAsCategory.nix (only "
              f"entry points live outside, and they are not collected)",
              file=sys.stderr)
        return 1
    if path.parent in catdirs:
        print(f"error: {path.parent} is the category dir itself, and a "
              f"category collects from its subdirectories only -- a file "
              f"sitting directly in it is collected by nothing. Put the file "
              f"in a subdirectory of it", file=sys.stderr)
        return 1

    name = target.stem
    for existing_path, existing_classes in modules.get(name, []):
        if cls in existing_classes:
            print(f"error: {cls}.{name} is already declared by "
                  f"{existing_path}; two same-named modules of one class "
                  f"MERGE silently rather than conflicting -- pick another "
                  f"name", file=sys.stderr)
            return 1
    if name in modules:
        others = ', '.join(sorted(
            f"{'/'.join(sorted(c))}.{name} ({p})"
            for p, c in modules[name]))
        print(f"warning: the name {name!r} already exists as {others}; a "
              f"different class declares cleanly, but grep for the name "
              f"before keeping it")
    if name in categories:
        print(f"error: {name!r} is also a category "
              f"({categories[name].parent}/); declaring a module of the same "
              f"name merges the two attributes -- this is exactly how `boot` "
              f"came to mean two different things. Pick another name",
              file=sys.stderr)
        return 1

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        BOILERPLATE.replace('@CLASS@', cls).replace('@DESC@', description))
    repo = pathlib.Path(subprocess.run(
        ['git', 'rev-parse', '--show-toplevel'],
        cwd=root, capture_output=True, text=True, check=True).stdout.strip())
    # `git -C <repo>` interprets pathspecs against the repo root, so hand it
    # the repo-relative form -- not the modules-dir-relative one.
    subprocess.run(['git', '-C', str(repo), 'add', '--',
                    str(path.resolve().relative_to(repo))], check=True)
    print(f"created {path} -- declares {cls}.{name}, collected via category "
          f"{category!r}; `git add`-ed")

    # The new module is imported by nothing yet, so `orphans` listing it is
    # the expected outcome, not a finding. Anything ELSE it reports was
    # already wrong before this command ran -- say so and fail rather than
    # let the new file hide in noise.
    new = {str(path)}
    findings = bool(collisions(root)) | bool(untracked(root))
    orphaned = orphans(root)
    stale = [f for f in orphaned if str(f[1]) not in new]
    if {str(f[1]) for f in orphaned} & new:
        print("ORPHAN (expected -- brand new): import it from a host or "
              "another module, or it installs nothing")
    if findings or stale:
        print("error: the checks above did not come back clean -- fix what "
              "they report before scaffolding here", file=sys.stderr)
        return 1
    return 0


def main():
    if len(sys.argv) < 2:
        print(__doc__); sys.exit(2)
    cmd = sys.argv[1]
    if cmd == 'add':
        if len(sys.argv) < 5:
            print(__doc__); sys.exit(2)
        sys.exit(add(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5:]))
    if len(sys.argv) != 3:
        print(__doc__); sys.exit(2)
    root = sys.argv[2]
    if cmd == 'collisions':
        sys.exit(1 if collisions(root) else 0)
    if cmd == 'orphans':
        sys.exit(1 if orphans(root) else 0)
    if cmd == 'untracked':
        sys.exit(1 if untracked(root) else 0)
    if cmd == 'check':
        bad = bool(collisions(root)) | bool(orphans(root)) | bool(untracked(root))
        print("no findings" if not bad else "", end="")
        sys.exit(1 if bad else 0)
    print(__doc__); sys.exit(2)

# Guarded so `add` (and the checks) stay importable for testing; nothing in
# the tree imports this module today, but unguarded main() made that impossible.
if __name__ == '__main__':
    main()
