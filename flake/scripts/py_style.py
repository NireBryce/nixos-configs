#!/usr/bin/env python3
"""Fail on the Python style rules this repo lints for, and on trailing
whitespace in .nix and .py files.

    py_style.py check [FILE...]    # no FILE: every git-tracked .py and .nix

Python rules, run through `ruff check --isolated` (the flag keeps the stray
ruff.toml under packages-config/.../linter-configs from changing the rule
set):

    F401  unused import             F541  f-string without a placeholder
    F841  unused local variable     E702  several statements on one line
    E731  `name = lambda ...`

Whitespace rule: no line in a .nix or .py file ends in a space or tab, which
is what `trim_trailing_whitespace` in .editorconfig asks for. Other file types
(markdown keeps two trailing spaces as a line break) are not checked.

Each finding prints as `file:line: RULE message`. A deliberate exception takes
a trailing `# noqa: <rule>` comment with its reason. ruff must be on PATH: it
is in the dev shell (flake/modules/dev-shell.nix), which CI runs preflight
in. Without it the check fails with a message (exit 3) rather than passing
unchecked; offline_checks.py skips this step instead, on purpose and out loud.

Exit status: 0 clean, 1 findings, 2 usage, 3 ruff missing.

Fixture test: tests/test_py_style.py.
"""
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
RULES = "F401,F541,F841,E702,E731"
WHITESPACE_SUFFIXES = {".nix", ".py"}
TRAILING_WHITESPACE = re.compile(r"[ \t]+$")
# ruff --output-format concise: `path:line:col: CODE [*] message`
RUFF_LINE = re.compile(r"^(?P<path>.+?):(?P<line>\d+):\d+: (?P<message>[A-Z]+\d+ .*)$")


def repo_root():
    result = subprocess.run(["git", "-C", str(HERE), "rev-parse", "--show-toplevel"],
                            capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit("py_style: not inside a git repository")
    return Path(result.stdout.strip())


def tracked_files(root):
    result = subprocess.run(
        ["git", "-C", str(root), "ls-files", "-z", "*.py", "*.nix"],
        capture_output=True, text=True)
    return [root / name for name in result.stdout.split("\0") if name]


def ruff_findings(paths):
    """['path:line: RULE message'] for the .py files in paths."""
    python_files = [str(path) for path in paths if path.suffix == ".py"]
    if not python_files:
        return []
    result = subprocess.run(
        ["ruff", "check", "--isolated", "--select", RULES, "--no-fix",
         "--output-format", "concise", *python_files],
        capture_output=True, text=True)
    findings = []
    for line in result.stdout.splitlines():
        match = RUFF_LINE.match(line)
        if match:
            message = match.group("message").replace(" [*]", "")
            findings.append(f"{match.group('path')}:{match.group('line')}: {message}")
    if result.returncode not in (0, 1):
        findings.append(f"ruff failed (exit {result.returncode}): "
                        f"{result.stderr.strip()[:300]}")
    elif result.returncode == 1 and not findings:
        findings.append(f"ruff reported findings py_style could not parse: "
                        f"{result.stdout.strip()[:300]}")
    return findings


def whitespace_findings(paths):
    findings = []
    for path in paths:
        if path.suffix not in WHITESPACE_SUFFIXES:
            continue
        for number, line in enumerate(path.read_text().split("\n"), start=1):
            if TRAILING_WHITESPACE.search(line):
                findings.append(f"{path}:{number}: W291 trailing whitespace")
    return findings


def cmd_check(paths):
    if not shutil.which("ruff"):
        print("py_style: ruff is not on PATH (it is in the dev shell: "
              "`nix develop ./flake`)", file=sys.stderr)
        return 3
    findings = ruff_findings(paths) + whitespace_findings(paths)
    for finding in findings:
        print(finding, file=sys.stderr)
    if findings:
        return 1
    print(f"py_style ok: {len(paths)} file(s) checked")
    return 0


def main(argv):
    if not argv or argv[0] != "check":
        print(__doc__, file=sys.stderr)
        return 2
    paths = [Path(name).resolve() for name in argv[1:]] or tracked_files(repo_root())
    return cmd_check(paths)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
