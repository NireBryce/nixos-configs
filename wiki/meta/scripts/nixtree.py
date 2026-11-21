#!/usr/bin/env python3
"""The tree's modules, categories and hosts as the files say them, for the
wiki scripts: the factcheck checks (tools/docchecks/) and wiki_gen.py's
generated tables both
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
    files = [nix_file for nix_file in modules.rglob('*.nix') if _visible(nix_file, modules)]
    key = (str(pathlib.Path(root).resolve()),
           tuple((str(nix_file), file_stat.st_mtime_ns, file_stat.st_size) for nix_file in files for file_stat in [nix_file.stat()]))
    if key not in _CATEGORIES:
        _CATEGORIES.clear()
        _CATEGORIES[key] = _read_categories(modules, files)
    return dict(_CATEGORIES[key])


def _read_categories(modules, files):
    # Paths as strings relative to modules/: pathlib's ancestor checks were
    # most of wiki-lint's time.
    base = len(str(modules)) + 1
    texts = {nix_file: COMMENT.sub('', nix_file.read_text()) for nix_file in files}      # each file read once
    rel = {nix_file: str(nix_file)[base:] for nix_file in files}
    module_dirs = {rel[nix_file].rpartition('/')[0] for nix_file in files if module_classes(nix_file, texts[nix_file])}
    flags_in, folders = {}, set()
    for nix_file in files:
        dir_name = rel[nix_file].rpartition('/')[0]
        flags_in.setdefault(dir_name, set()).update(FLAG.findall(texts[nix_file]))
        while dir_name:
            folders.add(dir_name)
            dir_name = dir_name.rpartition('/')[0]
    cats = {}
    for dir_name in sorted(folders):
        if '/' not in dir_name:
            continue                                   # an area
        flags = flags_in.get(dir_name, set())
        if flags == {'true'} or (flags != {'false'}
                                 and any(module_dir.startswith(dir_name + '/') for module_dir in module_dirs)):
            cats[dir_name.rpartition('/')[2]] = modules / dir_name
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
    def rel(nix_file):
        return nix_file.relative_to(modules).as_posix()

    doc = {'version': 1, 'classes': list(CLASS_KEYS), 'folders': [], 'defaults': [], 'admin': [],
           'categories': {category_name: {'dir': rel(category_dir), 'members': [], 'nested': [], 'flag': None}
                          for category_name, category_dir in all_categories(root).items()},
           'modules': {}, 'includes': {}, 'enables': {}}
    for nix_file in sorted(modules.rglob('*.nix')):
        if not _visible(nix_file, modules):
            continue
        classes = module_classes(nix_file)
        if not classes:
            continue
        name = module_name(nix_file)
        doc['modules'][name] = {'path': rel(nix_file), 'classes': [class_key for class_key in CLASS_KEYS if class_key in classes]}
        text = COMMENT.sub('', nix_file.read_text())
        for kind, pattern in (('includes', INCLUDES), ('enables', ENABLES)):
            for cls, names in pattern.findall(text):
                doc[kind].setdefault(name, {})[cls] = re.findall(r'"([\w-]+)"', names)
    return doc


def categories_under(root, category_dir):
    """The categories nested anywhere under category directory `d`."""
    prefix = str(category_dir) + '/'
    return [category for category in all_categories(root).values() if str(category).startswith(prefix)]


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
    category_dir = categories[name]
    modules = next(ancestor for ancestor in category_dir.parents if ancestor.name == 'modules')
    return {name} | {category.name for category in categories_under(modules.parent.parent, category_dir)}

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
    return {category_name: category_dir for category_name, category_dir in all_categories(root).items()
            if category_dir.relative_to(modules).parts[0] in areas}


# `nire-durandal = mkHost "x86_64-linux" ...;` / `nire-lysithea = mkDarwinHost
# "aarch64-darwin" ...;` -- hosts.nix's own two attrsets, `flake.
# nixosConfigurations` and `flake.darwinConfigurations`. The constructor name
# is what tells the two apart; no need to isolate which attrset a line sits
# in first.
HOST_LINE = re.compile(r'^\s*(nire-[\w-]+)\s*=\s*(mkHost|mkDarwinHost)\b', re.M)


def actual_hosts(root):
    """host name (with `nire-` prefix, matching how wiki/fleet/hosts.md writes it)
    -> class ('nixos' or 'darwin'), read straight from hosts.nix. The one
    roster: tools/docchecks/tree.py's roster() and wiki_gen.py's hosts.md
table both derive
    from it, so a host added to hosts.nix appears in both with no edit here.
    """
    hosts_file = root / 'flake' / 'modules' / 'host-config' / 'hosts.nix'
    text = COMMENT.sub('', hosts_file.read_text())
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
    for nix_file in category_dir.rglob('*.nix'):
        if _visible(nix_file, category_dir):
            classes |= module_classes(nix_file)
    return classes


def host_imports(root, categories, hosts):
    """host short-name -> set of category names it effectively imports --
    the names in its own `includes`, expanded through any umbrella category
    among them (see nested_category_names). `hosts` is the roster to
    compute rows for."""
    out = {}
    for host in hosts:
        config_path = root / 'flake' / 'modules' / 'host-config' / f'{host}-configuration.nix'
        if not config_path.exists():
            print(f"WARN  expected host file missing: {config_path}")
            continue
        text = COMMENT.sub('', config_path.read_text())
        literal = set()
        for _, names in INCLUDES.findall(text):
            literal.update(re.findall(r'"([\w-]+)"', names))
        effective = set()
        for literal_name in literal:
            effective |= nested_category_names(categories, literal_name)
        out[host] = effective
    return out
