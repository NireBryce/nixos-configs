#!/usr/bin/env python3
"""The tree's modules, categories and hosts as the files say them, for the
wiki scripts: check_docs.py's checks and wiki_gen.py's generated tables both
read the same thing, so it lives here and neither imports the other.

Read from the files rather than evaluated -- wiki-lint runs without nix and
on fixture trees; `just modules` compares this reading with what
dirs-as-categories actually evaluates to.
"""
import pathlib
import re

# The tree's modules and categories by dirs-as-categories' rules
# (wiki/config-structure/module-files.md), read from the files rather than evaluated: wiki-lint
# runs without nix and on fixture trees. `just modules` checks this reading
# against what dirs-as-categories actually evaluates to (flake.moduleGraph),
# so the two cannot drift apart silently.
CLASS_KEYS = ('nixos', 'homeManager', 'darwin')
COMMENT = re.compile(r'#[^\n]*')
# A key of a module file's top-level attribute set: the house style puts
# those at exactly four spaces (wiki/config-structure/module-style-guide.md), with `nixos =`,
# `homeManager.foo =` or `includes.nixos =`.
TOP_KEY = re.compile(r'(?m)^ {4}(\w+)(?:\.(\w+))?[\w.]*\s*=')
FLAG = re.compile(r'\bfolderIsCategory\s*=\s*(true|false)\s*;')
# `includes.<class> = [ "a" "b" ];` -- how a host or the home aggregate names
# what it includes.
INCLUDES = re.compile(r'includes\.(\w+)\s*=\s*\[(.*?)\]', re.S)


def _visible(path, base):
    """Not under a `_`-prefixed path component -- import-tree skips those."""
    return '/_' not in '/' + str(path)[len(str(base)) + 1:]


def module_classes(path, text=None):
    """The classes a module file declares -- its top-level class keys, and
    any class it has `includes` for -- or an empty set for a file that is
    not a module file (defaults.nix, a flake-parts module). `text`: the
    file's contents with comments stripped, when the caller has them."""
    if path.name == 'defaults.nix':
        return set()
    classes = set()
    for key, sub in TOP_KEY.findall(COMMENT.sub('', path.read_text()) if text is None else text):
        if key in CLASS_KEYS:
            classes.add(key)
        elif key == 'includes' and sub in CLASS_KEYS:
            classes.add(sub)
    return classes


_CATEGORIES = {}


def all_categories(root):
    """category name -> directory, for every category under flake/modules/:
    a folder below the top level with a subfolder holding a module file, or
    one whose files set folderIsCategory (`false` opts out).

    Called once per category and host by the checks above, so the reading
    is cached -- keyed on every file's path, mtime and size, so a fixture
    tree a test edits between calls is read afresh."""
    modules = root / 'flake' / 'modules'
    files = [p for p in modules.rglob('*.nix') if _visible(p, modules)]
    key = (str(pathlib.Path(root).resolve()),
           tuple((str(p), s.st_mtime_ns, s.st_size) for p in files for s in [p.stat()]))
    if key not in _CATEGORIES:
        _CATEGORIES.clear()
        _CATEGORIES[key] = _read_categories(modules, files)
    return dict(_CATEGORIES[key])


def _read_categories(modules, files):
    # Paths as strings relative to modules/: pathlib's ancestor checks were
    # most of wiki-lint's time.
    base = len(str(modules)) + 1
    texts = {p: COMMENT.sub('', p.read_text()) for p in files}      # each file read once
    rel = {p: str(p)[base:] for p in files}
    module_dirs = {rel[p].rpartition('/')[0] for p in files if module_classes(p, texts[p])}
    flags_in, folders = {}, set()
    for p in files:
        d = rel[p].rpartition('/')[0]
        flags_in.setdefault(d, set()).update(FLAG.findall(texts[p]))
        while d:
            folders.add(d)
            d = d.rpartition('/')[0]
    cats = {}
    for d in sorted(folders):
        if '/' not in d:
            continue                                   # an area
        flags = flags_in.get(d, set())
        if flags == {'true'} or (flags != {'false'}
                                 and any(m.startswith(d + '/') for m in module_dirs)):
            cats[d.rpartition('/')[2]] = modules / d
    return cats


ENABLES = re.compile(r'enables\.(\w+)\s*=\s*\[(.*?)\]', re.S)


def module_name(path):
    """A module's name: its filename, or its folder's for default.nix."""
    return path.parent.name if path.name == 'default.nix' else path.stem


def static_document(root):
    """flake.moduleGraph (format 1), as far as the files say it -- categories,
    modules with their classes, includes and enables -- for drawing without
    nix and for `just modules` to compare against the evaluated one."""
    modules = root / 'flake' / 'modules'
    rel = lambda p: p.relative_to(modules).as_posix()
    doc = {'version': 1, 'classes': list(CLASS_KEYS), 'folders': [], 'defaults': [], 'admin': [],
           'categories': {n: {'dir': rel(d), 'members': [], 'nested': [], 'flag': None}
                          for n, d in all_categories(root).items()},
           'modules': {}, 'includes': {}, 'enables': {}}
    for p in sorted(modules.rglob('*.nix')):
        if not _visible(p, modules):
            continue
        classes = module_classes(p)
        if not classes:
            continue
        name = module_name(p)
        doc['modules'][name] = {'path': rel(p), 'classes': [c for c in CLASS_KEYS if c in classes]}
        text = COMMENT.sub('', p.read_text())
        for kind, pattern in (('includes', INCLUDES), ('enables', ENABLES)):
            for cls, names in pattern.findall(text):
                doc[kind].setdefault(name, {})[cls] = re.findall(r'"([\w-]+)"', names)
    return doc


def categories_under(root, d):
    """The categories nested anywhere under category directory `d`."""
    prefix = str(d) + '/'
    return [c for c in all_categories(root).values() if str(c).startswith(prefix)]


def nested_category_names(categories, name):
    """`name` plus every category nested (at any depth) under its own
    directory -- e.g. `homelab` expands to itself plus `containers`,
    `git-forge`, ..., `virtualization`. Including a category includes
    everything beneath it, nested categories too (wiki/config-structure/module-files.md), so
    for the purposes of "does this host import category X" a host that
    includes the umbrella counts as importing X, even though X never appears
    literally in the host's own `includes`.
    """
    if name not in categories:
        return {name}
    d = categories[name]
    modules = next(a for a in d.parents if a.name == 'modules')
    return {name} | {c.name for c in categories_under(modules.parent.parent, d)}

def find_categories(root):
    """category name -> its directory, for every category under
    flake/modules/general-config/, flake/modules/hardware-config/,
    flake/modules/homelab-config/ and flake/modules/users-config/ -- the
    areas categories/00-INDEX.md actually
    indexes (packages-config/* and host-config/*
    are deliberately excluded there, see that file's own header, so this
    check has nothing to compare them against and doesn't look).
    """
    modules = root / 'flake' / 'modules'
    areas = ('general-config', 'hardware-config', 'homelab-config', 'users-config')
    return {n: d for n, d in all_categories(root).items()
            if d.relative_to(modules).parts[0] in areas}


# `nire-durandal = mkHost "x86_64-linux" ...;` / `nire-lysithea = mkDarwinHost
# "aarch64-darwin" ...;` -- hosts.nix's own two attrsets, `flake.
# nixosConfigurations` and `flake.darwinConfigurations`. The constructor name
# is what tells the two apart; no need to isolate which attrset a line sits
# in first.
HOST_LINE = re.compile(r'^\s*(nire-[\w-]+)\s*=\s*(mkHost|mkDarwinHost)\b', re.M)


def actual_hosts(root):
    """host name (with `nire-` prefix, matching how wiki/fleet/hosts.md writes it)
    -> class ('nixos' or 'darwin'), read straight from hosts.nix. The one
    roster: check_docs.roster() and wiki_gen.py's hosts.md table both derive
    from it, so a host added to hosts.nix appears in both with no edit here.
    """
    p = root / 'flake' / 'modules' / 'host-config' / 'hosts.nix'
    text = COMMENT.sub('', p.read_text())
    return {name: ('darwin' if ctor == 'mkDarwinHost' else 'nixos')
            for name, ctor in HOST_LINE.findall(text)}


def category_classes(category_dir):
    """The classes declared by any module file under this category's own
    directory tree, read statically (module_classes). A nested category's
    files live physically under the umbrella's tree too, so this walks
    straight through a nested category rather than stopping at it: what the
    Class(es) column claims is "what including this name actually wires in".
    Every category exists in every class (dirs-as-categories defines all of
    them, even empty), so presence of the *attribute* proves nothing;
    presence of a declaration under the tree does.
    """
    classes = set()
    for p in category_dir.rglob('*.nix'):
        if _visible(p, category_dir):
            classes |= module_classes(p)
    return classes


def host_imports(root, categories, hosts):
    """host short-name -> set of category names it effectively imports --
    the names in its own `includes`, expanded through any umbrella category
    among them (see nested_category_names). `hosts` is the roster to
    compute rows for."""
    out = {}
    for host in hosts:
        p = root / 'flake' / 'modules' / 'host-config' / f'{host}-configuration.nix'
        if not p.exists():
            print(f"WARN  expected host file missing: {p}")
            continue
        text = COMMENT.sub('', p.read_text())
        literal = set()
        for _, names in INCLUDES.findall(text):
            literal.update(re.findall(r'"([\w-]+)"', names))
        effective = set()
        for n in literal:
            effective |= nested_category_names(categories, n)
        out[host] = effective
    return out
