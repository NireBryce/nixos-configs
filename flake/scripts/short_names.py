#!/usr/bin/env python3
"""Flag one-character variable names in the repo's Python files.

A name like `r`, `p` or `m` says nothing at the point of use, and the same
letter meant different things in neighbouring functions (`r` was a result, a
repo, and an imported module in three test files). Use a name that says what
the value is: `result`, `repo`, `match`, `path`. `_` (a value being ignored) is
the only one-character name allowed.

    short_names.py check            # fail on any file over its baseline
    short_names.py list [PATH...]   # print every site, file:line: name
    short_names.py update           # rewrite the baseline to current counts

What counts: a variable, a function parameter, an `except ... as` name, a
function or class name, and an `import ... as` alias. Names in comments and
strings do not count (the check reads the syntax tree).

A file under `short-names-baseline.json` is one nobody has cleaned yet. Its
count may not rise, and `check` also fails when the count has dropped below the
baseline, so the baseline only ever shrinks: run `update` and commit the
smaller file. A file not in the baseline must have no one-character names.
Every file the baseline does not list is held to zero, including new files.

A site that truly needs a one-character name (coordinates named `x` and `y`
in a geometry helper, say) takes a trailing `# short-name: ok` comment on the
line, which the check skips. Say why next to it; none exist so far.

Fixture test: `tests/test_short_names.py`. It builds a file with each kind of
site and asserts they are all found.
"""
import ast
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
BASELINE = HERE / "short-names-baseline.json"
ALLOWED = {"_"}
PRAGMA = "# short-name: ok"


def repo_root():
    result = subprocess.run(["git", "-C", str(HERE), "rev-parse", "--show-toplevel"],
                            capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit("short_names: not inside a git repository")
    return Path(result.stdout.strip())


def tracked_python_files(root):
    result = subprocess.run(["git", "-C", str(root), "ls-files", "-z", "*.py"],
                            capture_output=True, text=True)
    return [name for name in result.stdout.split("\0") if name]


def is_short(name):
    return name is not None and len(name) == 1 and name not in ALLOWED


def find_sites(source):
    """-> sorted list of (line, name) for each one-character name in `source`.

    Raises SyntaxError when the source does not parse."""
    lines = source.splitlines()
    sites = set()
    for node in ast.walk(ast.parse(source)):
        if isinstance(node, ast.Name):
            candidates = [(node.id, node.lineno)]
        elif isinstance(node, ast.arg):
            candidates = [(node.arg, node.lineno)]
        elif isinstance(node, ast.ExceptHandler):
            candidates = [(node.name, node.lineno)]
        elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            candidates = [(node.name, node.lineno)]
        elif isinstance(node, ast.alias):
            candidates = [(node.asname, getattr(node, "lineno", 0))]
        else:
            continue
        for name, line in candidates:
            line_text = lines[line - 1] if 0 < line <= len(lines) else ""
            if is_short(name) and PRAGMA not in line_text:
                sites.add((line, name))
    return sorted(sites)


def count_by_file(root, files):
    counts = {}
    for name in files:
        try:
            source = (root / name).read_text()
            sites = find_sites(source)
        except (SyntaxError, UnicodeDecodeError, OSError) as error:
            print(f"short_names: skipped {name}: {error}", file=sys.stderr)
            continue
        if sites:
            counts[name] = len(sites)
    return counts


def load_baseline():
    if not BASELINE.exists():
        return {}
    return json.loads(BASELINE.read_text())


def write_baseline(counts):
    BASELINE.write_text(json.dumps(dict(sorted(counts.items())), indent=2) + "\n")


def cmd_check(root):
    counts = count_by_file(root, tracked_python_files(root))
    baseline = load_baseline()
    problems = []
    for name, count in sorted(counts.items()):
        allowed = baseline.get(name, 0)
        if count > allowed:
            problems.append(
                f"{name}: {count} one-character name(s), baseline allows {allowed}. "
                f"Rename them (`short_names.py list {name}` shows where).")
        elif count < allowed:
            problems.append(
                f"{name}: down to {count} from a baseline of {allowed}. "
                f"Run `short_names.py update` and commit the smaller baseline.")
    for name in sorted(set(baseline) - set(counts)):
        problems.append(
            f"{name}: now clean (or removed) but still in the baseline. "
            f"Run `short_names.py update` and commit the smaller baseline.")
    for problem in problems:
        print(problem, file=sys.stderr)
    if problems:
        return 1
    print(f"short_names ok: {len(counts)} file(s) still baselined, "
          f"{sum(counts.values())} name(s) left to rename")
    return 0


def cmd_list(root, paths):
    files = paths or tracked_python_files(root)
    shown = 0
    for name in files:
        for line, variable in find_sites((root / name).read_text()):
            print(f"{name}:{line}: {variable}")
            shown += 1
    print(f"{shown} site(s)", file=sys.stderr)
    return 0


def cmd_update(root):
    counts = count_by_file(root, tracked_python_files(root))
    write_baseline(counts)
    print(f"wrote {BASELINE.name}: {len(counts)} file(s)")
    return 0


def main(argv):
    command = argv[0] if argv else "check"
    root = repo_root()
    if command == "check":
        return cmd_check(root)
    if command == "list":
        return cmd_list(root, argv[1:])
    if command == "update":
        return cmd_update(root)
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
