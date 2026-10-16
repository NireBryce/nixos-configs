#!/usr/bin/env python3
"""Checks over the module tree, for the things evaluation cannot report.

dirs-as-categories (the flake input that builds flake.modules from
flake/modules/) already refuses what used to fail silently here: two
modules or a module and a category sharing a name, a mistyped class key, a
name in `includes` that doesn't exist (wiki/module-files.md). It also
reports orphans -- modules nothing reaches -- as `nix flake check`'s
module-orphans (flake/modules/checks.nix turns it on). What is left:

  untracked   A .nix file git doesn't know about: flakes in a git repo
              ignore it, so it silently does not exist.

  drift       wiki-lint reads categories, modules, includes and enables
              from the files without evaluating (check_wiki.py's
              static_document); this compares that reading with the
              evaluated graph, so the two rules cannot drift apart.

The graph is `nix eval .#moduleGraph`, through a `path:` flake so
untracked files count.

    modules.py untracked  <modules-dir>
    modules.py drift      <modules-dir>
    modules.py check      <modules-dir>     # both; non-zero exit on any finding

    modules.py add <modules-dir> <class> <category>/<subdir>/<name>.nix [description words...]
                           # scaffold a new module inside a category, in the
                           # shape wiki/module-files.md describes; `git add`s
                           # the file (flakes ignore untracked ones) and runs
                           # the checks above immediately. The new module is
                           # reported as an orphan on purpose -- nothing
                           # includes it yet.
"""
import json, pathlib, subprocess, sys

# Where each finding kind's rule and history live, printed once under that
# kind's findings (#460): the moment a check fires is the moment its lesson
# is worth reading.
SEE = {
    'untracked': "AGENTS.md, 'git add before nix eval'",
    'drift':     "wiki/module-files.md; fix whichever reading is wrong, "
                 "check_wiki.py's module_classes/all_categories or the file",
}


def see(kind):
    print(f"           -> see {SEE[kind]}")


def graph(root, run=subprocess.run):
    """flake.moduleGraph for the flake around <modules-dir>, or exit with why."""
    flake = pathlib.Path(root).resolve().parent
    try:
        r = run(['nix', 'eval', '--json', f'path:{flake}#moduleGraph'],
                capture_output=True, text=True)
    except FileNotFoundError:
        sys.exit('error: nix is not installed; these checks read what the flake evaluates to')
    if r.returncode:
        lines = r.stderr.strip().splitlines()
        sys.exit(f'error: nix eval of moduleGraph failed: {lines[-1] if lines else r.returncode}')
    return json.loads(r.stdout)


def ancestors(path):
    p = pathlib.PurePosixPath(path)
    return [str(a) for a in p.parents if str(a) != '.']


def untracked(root):
    """A new .nix file that git doesn't know about yet.

    AGENTS.md, 'git add before nix eval': flakes in a git repo ignore
    untracked files, so a brand-new module silently does not exist as far as
    `nix eval` or a build is concerned -- no error, just a module that was
    never there. `git status` already reports this, but nothing surfaces it
    at the moment it actually matters (right before a check/build).
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
    if hits:
        see('untracked')
    return hits


def static_document(root):
    """check_wiki.py's file-only reading of the tree. The script is loaded
    from this checkout (wiki/scripts/), the tree read from <modules-dir>,
    which sits at <repo>/flake/modules."""
    import importlib.util
    script = pathlib.Path(__file__).resolve().parents[2] / 'wiki' / 'scripts' / 'check_wiki.py'
    spec = importlib.util.spec_from_file_location('check_wiki', script)
    cw = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(cw)
    return cw.static_document(pathlib.Path(root).resolve().parents[1])


def drift(doc, static):
    """Where the file-only reading disagrees with the evaluated graph."""
    views = {
        'category': lambda d: {n: c['dir'] for n, c in d['categories'].items()},
        'module':   lambda d: {n: (m['path'], sorted(m['classes'])) for n, m in d['modules'].items()},
        'includes': lambda d: d.get('includes') or {},
        'enables':  lambda d: d.get('enables') or {},
    }
    hits = []
    for kind, view in views.items():
        a, b = view(doc), view(static)
        for name in sorted(set(a) | set(b)):
            if a.get(name) != b.get(name):
                hits.append(f"DRIFT      {kind} {name!r}: evaluated {a.get(name)!r}, "
                            f"read from the files {b.get(name)!r}")
    for h in hits:
        print(h)
    if hits:
        see('drift')
    return hits


# The classes dirs-as-categories is configured with (flake/flake.nix): a key
# outside these is refused at evaluation, so refuse it here first.
CLASSES = ('nixos', 'homeManager', 'darwin')

# wiki/module-files.md's shape and wiki/module-style-guide.md's formatting:
# the pointer line, opening brackets on the same line, four-space indent, and
# the `# # description` comment as the first line of the body. The class
# module is `_:` rather than `{ ... }:` -- statix flags the empty pattern and
# a fresh file would raise the lint ratchet; whoever fleshes the module out
# will destructure `config`/`pkgs` anyway. No `{ lib, ... }:` header until
# the body uses `lib`: deadnix would flag it unused.
#
# Tokens, not str.format: the text is full of literal Nix braces.
BOILERPLATE = '''# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    @CLASS@ = _: {
        # # description = "@DESC@";
    };
}
'''


def add(root, cls, target, description, run=subprocess.run):
    """Scaffold a module file inside a category.

    The target must sit under a category, since a module outside every
    category is collected by nothing; the class must be one dirs-as-categories
    knows; a name already taken by a module or a category is refused, since
    dirs-as-categories would refuse the whole tree. The file is `git add`-ed --
    flakes in a git repo ignore untracked files -- and the checks run
    immediately, so a mistake is caught this second rather than at the next
    build.
    """
    if cls not in CLASSES:
        print(f"error: class {cls!r} is not one dirs-as-categories knows "
              f"({', '.join(CLASSES)})", file=sys.stderr)
        return 1
    target = pathlib.PurePosixPath(target)
    if target.is_absolute() or '..' in target.parts:
        print(f"error: target must be a relative path under {root}", file=sys.stderr)
        return 1
    if target.suffix != '.nix' or len(target.parts) < 2:
        print("error: target must name a .nix file inside a category, e.g. "
              "general-config/system/my-thing/my-thing.nix", file=sys.stderr)
        return 1
    if target.name in ('default.nix', 'defaults.nix'):
        print("error: name the file after the module; default.nix and defaults.nix "
              "mean something else here (wiki/module-files.md)", file=sys.stderr)
        return 1
    description = ' '.join(description) if description else "TODO: one line"
    if '"' in description or '${' in description:
        # Either would break the "..." string in the generated Nix: a quote
        # terminates it, `${` interpolates.
        print('error: description must not contain `"` or `${`', file=sys.stderr)
        return 1

    path = pathlib.Path(root) / target
    if path.exists():
        print(f"error: {path} already exists", file=sys.stderr)
        return 1

    doc = graph(root, run)
    category_at = {c['dir']: name for name, c in doc['categories'].items()}
    category = next((category_at[a] for a in ancestors(target) if a in category_at), None)
    if category is None:
        print(f"error: {target} sits outside every category; a module must be "
              f"under a category's folder (only entry points live outside, and "
              f"they are collected by nothing)", file=sys.stderr)
        return 1
    name = target.stem
    if name in doc['modules'] or name in doc['categories']:
        where = doc['modules'][name]['path'] if name in doc['modules'] else doc['categories'][name]['dir']
        print(f"error: the name {name!r} is taken ({where}); modules and "
              f"categories share one namespace -- pick another name", file=sys.stderr)
        return 1

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(BOILERPLATE.replace('@CLASS@', cls).replace('@DESC@', description))
    repo = pathlib.Path(subprocess.run(
        ['git', 'rev-parse', '--show-toplevel'],
        cwd=root, capture_output=True, text=True, check=True).stdout.strip())
    # `git -C <repo>` interprets pathspecs against the repo root, so hand it
    # the repo-relative form -- not the modules-dir-relative one.
    subprocess.run(['git', '-C', str(repo), 'add', '--',
                    str(path.resolve().relative_to(repo))], check=True)
    print(f"created {path} -- the {cls} module {name!r}, in category {category!r}; "
          f"`git add`-ed")

    # The new module is reached by nothing yet, so the graph listing it as an
    # orphan is the expected outcome, not a finding. Any OTHER orphan was
    # already wrong before this command ran -- say so and fail rather than
    # let the new file hide in noise.
    stale_untracked = bool(untracked(root))
    orphaned = graph(root, run).get('orphans', [])
    stale = [n for n in orphaned if n != name]
    if name in orphaned:
        print("ORPHAN (expected -- brand new): include it from a host or "
              "another module, or it installs nothing")
    for n in stale:
        print(f"ORPHAN     {n!r} is reached by nothing (`nix flake check` fails on it too)")
    if stale_untracked or stale:
        print("error: the checks above did not come back clean -- fix what "
              "they report before scaffolding here", file=sys.stderr)
        return 1
    return 0


def main(argv=None, run=subprocess.run):
    argv = list(sys.argv[1:] if argv is None else argv)
    if not argv:
        print(__doc__); return 2
    cmd = argv[0]
    if cmd == 'add':
        if len(argv) < 4:
            print(__doc__); return 2
        return add(argv[1], argv[2], argv[3], argv[4:], run)
    if len(argv) != 2:
        print(__doc__); return 2
    root = argv[1]
    if cmd == 'untracked':
        return 1 if untracked(root) else 0
    if cmd == 'drift':
        return 1 if drift(graph(root, run), static_document(root)) else 0
    if cmd == 'check':
        bad = bool(untracked(root)) | bool(drift(graph(root, run), static_document(root)))
        print("no findings" if not bad else "", end="")
        return 1 if bad else 0
    print(__doc__); return 2


if __name__ == '__main__':
    sys.exit(main())
