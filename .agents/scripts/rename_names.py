#!/usr/bin/env python3
"""Rename Python variables by syntax tree, and check what a rename can break.

Replaces the hand-assembled `sed` and one-off AST scripts used for the
2026-11-15 pass that removed one-character names (lesson §54). A text
replace renames letters in strings and comments and misses nothing it should
not touch only by luck; this edits identifier nodes by position.

    rename_names.py list FILE...
        Each function's one-character names, with the source lines, so a
        name can be chosen from context. `_` is skipped.
    rename_names.py rename FILE SCOPE OLD=NEW [OLD=NEW ...]
        Rename inside SCOPE: a function or class path (`main`,
        `Runner.run_commit`, `setUp@348` when the name is not unique; the
        number is the line of the `def`), or `*` for the whole file. Edits
        variables, parameters, `except ... as` names and `import ... as`
        aliases. Refuses, writing nothing, when NEW already names something in
        the scope. Then re-parses the file and, when `ruff` is on PATH, runs
        `ruff check --select F821` on it.
    rename_names.py callers [--base REV]
        For every .py file that differs from REV (default HEAD), find
        functions whose parameter names changed and print each call, anywhere
        in the tracked .py files, that passes the old name as a keyword.
        Run it after renaming parameters; a keyword call to a renamed
        parameter is a TypeError, or goes silently into `**kwargs`.

What it does not do. It renames one scope at a time with names you choose;
the same letter can mean different things in different functions, and no
rule picks the right name for each. Read the diff of what it changed. A
parameter's name is a keyword for its callers, which `callers` finds only
when the call is on one line with the function name. Attribute names
(`self.r`) and keyword arguments (`f(r=1)`) are not variables and are left
alone. Needs Python 3.12 or newer for correct positions inside f-strings.
"""
import ast
import re
import shutil
import subprocess
import sys
from pathlib import Path


def parse_scope_spec(spec):
    """'a.b@12' -> (['a', 'b'], 12); the line is None when absent."""
    path, _, line = spec.partition("@")
    return path.split("."), int(line) if line else None


def find_scope(tree, spec):
    """The tree node named by SCOPE: the module for '*', else a def or class.

    Raises ValueError when the name is missing or matches more than one
    definition (the message lists their lines)."""
    if spec == "*":
        return tree
    names, line = parse_scope_spec(spec)
    node = tree
    for depth, name in enumerate(names):
        matches = [
            child for child in ast.walk(node)
            if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef))
            and child.name == name and child is not node]
        if depth == len(names) - 1 and line is not None:
            matches = [child for child in matches if child.lineno == line]
        if not matches:
            raise ValueError(f"no function or class {spec!r}")
        if len(matches) > 1:
            where = ", ".join(str(child.lineno) for child in matches)
            raise ValueError(
                f"{name!r} is ambiguous (defined at lines {where}); "
                f"write {name}@LINE")
        node = matches[0]
    return node


def names_used(scope):
    """Every name the scope binds or reads: variables, parameters, aliases,
    nested definitions."""
    used = set()
    for node in ast.walk(scope):
        if isinstance(node, ast.Name):
            used.add(node.id)
        elif isinstance(node, ast.arg):
            used.add(node.arg)
        elif isinstance(node, ast.ExceptHandler) and node.name:
            used.add(node.name)
        elif isinstance(node, ast.alias):
            used.add(node.asname or node.name.split(".")[0])
        elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            used.add(node.name)
    return used


def locate_after(line_bytes, start, keyword):
    """Byte offset just past `keyword` (e.g. b' as ') searched from start."""
    found = line_bytes.find(keyword, start)
    return None if found < 0 else found + len(keyword)


def collect_edits(scope, lines, mapping):
    """-> list of (line_index, byte_column, old, new)."""
    edits = []
    for node in ast.walk(scope):
        if isinstance(node, ast.Name) and node.id in mapping:
            edits.append((node.lineno - 1, node.col_offset, node.id))
        elif isinstance(node, ast.arg) and node.arg in mapping:
            edits.append((node.lineno - 1, node.col_offset, node.arg))
        elif isinstance(node, ast.ExceptHandler) and node.name in mapping:
            column = locate_after(lines[node.lineno - 1], node.col_offset, b" as ")
            if column is not None:
                edits.append((node.lineno - 1, column, node.name))
        elif isinstance(node, ast.alias) and node.asname in mapping:
            line_index = node.lineno - 1
            column = locate_after(lines[line_index], node.col_offset, b" as ")
            if column is not None:
                edits.append((line_index, column, node.asname))
    return [(line, column, old, mapping[old]) for line, column, old in sorted(set(edits))]


def apply_edits(lines, edits):
    """Edit right to left on each line so earlier columns stay valid."""
    for line_index, column, old, new in sorted(edits, reverse=True):
        old_bytes, new_bytes = old.encode(), new.encode()
        line_bytes = lines[line_index]
        if line_bytes[column:column + len(old_bytes)] != old_bytes:
            raise RuntimeError(
                f"line {line_index + 1}: expected {old!r} at byte {column}, "
                f"found {line_bytes[column:column + len(old_bytes)]!r}")
        lines[line_index] = line_bytes[:column] + new_bytes + line_bytes[column + len(old_bytes):]


def rename_in_source(source, spec, mapping):
    """-> (new_source, edit_count). Raises ValueError on a bad scope or a
    name collision."""
    tree = ast.parse(source)
    scope = find_scope(tree, spec)
    used = names_used(scope)
    for new in mapping.values():
        if not new.isidentifier():
            raise ValueError(f"{new!r} is not a valid name")
        if new in used:
            raise ValueError(f"{new!r} is already used in {spec!r}")
    lines = source.encode().split(b"\n")
    edits = collect_edits(scope, lines, mapping)
    apply_edits(lines, edits)
    new_source = b"\n".join(lines).decode()
    ast.parse(new_source)
    return new_source, len(edits)


def short_names_by_function(source):
    """-> {function path: sorted line numbers} for one-character names."""
    hits = {}

    def visit(node, scope):
        for child in ast.iter_child_nodes(node):
            child_scope = scope
            if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
                child_scope = scope + [child.name]
            name = None
            if isinstance(child, ast.Name):
                name = child.id
            elif isinstance(child, ast.arg):
                name = child.arg
            elif isinstance(child, ast.ExceptHandler):
                name = child.name
            if name and len(name) == 1 and name != "_":
                hits.setdefault(".".join(scope) or "<module>", set()).add(child.lineno)
            visit(child, child_scope)

    visit(ast.parse(source), [])
    return {scope: sorted(lines) for scope, lines in hits.items()}


def cmd_list(files):
    for name in files:
        source = Path(name).read_text()
        source_lines = source.splitlines()
        print(f"##### {name}")
        for scope, line_numbers in short_names_by_function(source).items():
            print(f"--- {scope}")
            for number in line_numbers:
                print(f"{number}: {source_lines[number - 1]}")
    return 0


def run_ruff(path):
    if not shutil.which("ruff"):
        return "ruff not on PATH; undefined names not checked"
    result = subprocess.run(
        ["ruff", "check", "--isolated", "--select", "F821", "--no-cache", str(path)],
        capture_output=True, text=True)
    return "ruff F821: ok" if result.returncode == 0 else result.stdout.strip()


def cmd_rename(path, spec, pairs):
    mapping = {}
    for pair in pairs:
        old, _, new = pair.partition("=")
        if not old or not new:
            print(f"rename_names: expected OLD=NEW, got {pair!r}", file=sys.stderr)
            return 2
        mapping[old] = new
    target = Path(path)
    try:
        new_source, count = rename_in_source(target.read_text(), spec, mapping)
    except (ValueError, SyntaxError, RuntimeError) as error:
        print(f"rename_names: {error}", file=sys.stderr)
        return 1
    target.write_text(new_source)
    print(f"{count} edit(s) in {path}:{spec}")
    print(run_ruff(target))
    return 0


def parameter_lists(source):
    """-> {function name: [parameter-name lists, one per definition]}."""
    found = {}
    for node in ast.walk(ast.parse(source)):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            arguments = node.args
            names = [arg.arg for arg in
                     arguments.posonlyargs + arguments.args + arguments.kwonlyargs]
            found.setdefault(node.name, []).append(names)
    return found


def renamed_parameters(old_source, new_source):
    """-> {function name: {old parameter: new parameter}}."""
    before, after = parameter_lists(old_source), parameter_lists(new_source)
    renamed = {}
    for function, old_lists in before.items():
        for old_names, new_names in zip(old_lists, after.get(function, [])):
            for old, new in zip(old_names, new_names):
                if old != new:
                    renamed.setdefault(function, {})[old] = new
    return renamed


def git_output(*args):
    result = subprocess.run(["git", *args], capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(f"rename_names: git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout


def keyword_calls(renamed, texts):
    """-> list of 'path:line: function old=' for calls passing an old name.

    `texts` is {path: source}. Matches a call where the function name,
    `(`, and `old=` are on one line."""
    problems = []
    for path, source in texts.items():
        for number, line in enumerate(source.splitlines(), 1):
            for function, names in renamed.items():
                if not re.search(rf"\b{re.escape(function)}\(", line):
                    continue
                for old in names:
                    if re.search(rf"[(,\s]{re.escape(old)}=", line):
                        problems.append(f"{path}:{number}: {function} {old}=")
    return problems


def cmd_callers(base):
    changed = [name for name in git_output("diff", base, "--name-only").split("\n")
               if name.endswith(".py")]
    renamed = {}
    for name in changed:
        old = subprocess.run(["git", "show", f"{base}:{name}"],
                             capture_output=True, text=True)
        if old.returncode != 0:
            continue
        try:
            renamed.update(renamed_parameters(old.stdout, Path(name).read_text()))
        except SyntaxError as error:
            print(f"rename_names: {name}: {error}", file=sys.stderr)
    tracked = [name for name in git_output("ls-files", "*.py").split("\n") if name]
    texts = {name: Path(name).read_text(errors="replace") for name in tracked}
    problems = keyword_calls(renamed, texts)
    for problem in problems:
        print(problem)
    print(f"{len(renamed)} function(s) with renamed parameters; "
          f"{len(problems)} keyword call(s) to the old name")
    return 1 if problems else 0


def main(argv):
    if len(argv) >= 2 and argv[0] == "list":
        return cmd_list(argv[1:])
    if len(argv) >= 4 and argv[0] == "rename":
        return cmd_rename(argv[1], argv[2], argv[3:])
    if argv and argv[0] == "callers":
        base = argv[argv.index("--base") + 1] if "--base" in argv else "HEAD"
        return cmd_callers(base)
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
