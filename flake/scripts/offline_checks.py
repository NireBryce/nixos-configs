#!/usr/bin/env python3
"""The checks that need neither nix nor `just`, for hooks on a machine that
has neither working -- a Claude Code cloud container has nix installed but no
route to fetch the flake inputs, and no `just` at all.

  offline_checks.py staged       fast, per commit: what is staged, as staged
  offline_checks.py preflight    `just preflight`'s steps that can run here

.githooks/pre-commit runs `staged` (and .githooks/pre-push runs `preflight`)
only when flake/scripts/with-nix-tools.sh exits 75, i.e. when the full
checks cannot run; where they can, these hooks leave the full checks alone.
CI still runs `just preflight` in full, so this is the same checklist with
the parts that need nix named and left out, never a second checklist.

`staged` is what a nix-less commit can still be held to:
  .py            compiles (the index version, not the worktree's)
  .sh .bash, .githooks/*   `bash -n`
  .json, .toml   parses
  .nix           `nix-instantiate --parse` (syntax only; fetches nothing)
  wiki lint      factcheck check -- but factcheck is the factcheck flake
                 input, which a nix-less environment cannot fetch, so
                 this step runs only where the tool is already on PATH
                 (a dev shell) and is left to CI otherwise, said out loud
It replaces statix/deadnix, not equals them: a lint regression still has to
be caught by CI.

`preflight` expands the preflight recipe the way test_preflight_mirror.py
does and runs every `python3 <script>` step, concurrently. NEEDS_NIX lists
the steps it must skip and why; a step in neither place is run, so a new
python step is covered by default and a new nix-dependent one fails loudly
the first time it runs here, rather than being silently absent. The
wiki-lint step is the factcheck wrapper (a .sh, not a python3 line), so it
lands in NOT_PYTHON_REASONS with its own stated reason.

Exit status: 0 all pass, 1 a check failed.
"""
import concurrent.futures
import importlib.util
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tomllib

REPO = pathlib.Path(__file__).resolve().parents[2]

# preflight steps that cannot run without nix, keyed by script path.
NEEDS_NIX = {
    "wiki/meta/scripts/test_wiki_gen.py":
        "its fixtures evaluate a flake (7 of 15 fail without nix)",
    "flake/scripts/modules.py":
        "reads the module tree through nix eval",
}
# Steps that need a tool from the dev shell, run only where it is on PATH:
# script path -> the executable it needs.
NEEDS_TOOL = {
    "flake/scripts/py_style.py": "ruff",
    "flake/scripts/tests/test_py_style.py": "ruff",
}
# Steps that are not python: skipped, with the reason shown.
NOT_PYTHON = "not a python3 step (needs nix, or warn-only)"
# Known non-python steps, with their own stated reason (keyed by the first
# token of the command line).
NOT_PYTHON_REASONS = {
    "flake/scripts/factcheck.sh":
        "wiki lint via the factcheck flake input -- needs nix; CI runs it",
    "flake/scripts/factcheck-test.sh":
        "factcheck's fixture tests live in the flake input's source",
}
# Run, but with an extra flag appended.
EXTRA_ARGS = {}


def git(*args, check=True):
    return subprocess.run(["git", "-C", str(REPO), *args], check=check,
                          capture_output=True, text=True).stdout


def staged_paths():
    out = git("diff", "--cached", "--name-only", "--diff-filter=ACMR", "-z")
    return [path for path in out.split("\0") if path]


def staged_text(path):
    return subprocess.run(["git", "-C", str(REPO), "show", f":{path}"],
                          capture_output=True).stdout


def check_staged_file(path):
    """Problems with one staged file, as strings."""
    data = staged_text(path)
    name = pathlib.PurePosixPath(path)
    if name.suffix == ".py":
        try:
            compile(data, path, "exec")
        except SyntaxError as error:
            return [f"{path}:{error.lineno}: python syntax: {error.msg}"]
    elif name.suffix in (".sh", ".bash") or path.startswith(".githooks/"):
        result = subprocess.run(["bash", "-n"], input=data, capture_output=True)
        if result.returncode:
            return [f"{path}: bash -n: {result.stderr.decode().strip()}"]
    elif name.suffix == ".json":
        try:
            json.loads(data)
        except ValueError as error:
            return [f"{path}: json: {error}"]
    elif name.suffix == ".toml":
        try:
            tomllib.loads(data.decode())
        except (tomllib.TOMLDecodeError, UnicodeDecodeError) as error:
            return [f"{path}: toml: {error}"]
    elif name.suffix == ".nix" and shutil.which("nix-instantiate"):
        result = subprocess.run(["nix-instantiate", "--parse", "-"], input=data,
                           capture_output=True)
        if result.returncode:
            return [f"{path}: nix parse: {result.stderr.decode().strip()[:400]}"]
    return []


def run_wiki_lint():
    """The wiki lint, when this environment has the tool. factcheck is the
    factcheck flake input; a nix-less environment cannot fetch it, so
    there the step is skipped (None) and the caller says so. Unlike the
    ancestor checker there is no --skip=generated here: a region needing
    nix reports a REVIEW finding instead of failing, so a full run is
    safe wherever the tool exists."""
    if not shutil.which("factcheck"):
        return None
    result = subprocess.run(["factcheck", "check"], capture_output=True, text=True)
    return [] if result.returncode == 0 else (result.stdout + result.stderr).strip().splitlines()


def cmd_staged():
    problems = []
    paths = staged_paths()
    for path in paths:
        problems += check_staged_file(path)
    lint = run_wiki_lint()
    lint_note = ("and the wiki lint passed" if lint == [] else
                 "the wiki lint skipped (no factcheck on PATH)")
    if lint:
        problems += lint
    if problems:
        print("offline checks failed:", file=sys.stderr)
        for line in problems:
            print(f"  {line}", file=sys.stderr)
        return 1
    print(f"offline checks: {len(paths)} staged file(s) {lint_note}; "
          f"statix/deadnix and the flake checks did not run here, CI runs "
          f"them.")
    return 0


def preflight_lines():
    spec = importlib.util.spec_from_file_location(
        "preflight_mirror", REPO / "flake/scripts/tests/test_preflight_mirror.py")
    mirror = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mirror)
    return mirror.expand("preflight", (REPO / ".justfile").read_text().splitlines())


def classify(lines):
    """[(argv|None, label, reason|None)] -- argv None means skipped."""
    out = []
    for line in lines:
        match = re.fullmatch(r"(cd flake && )?python3 (\S+\.py)(?: (.*))?", line)
        if not match:
            first = line.split()[0] if line.split() else ""
            out.append((None, line,
                        NOT_PYTHON_REASONS.get(first, NOT_PYTHON)))
            continue
        # `cd flake && python3 scripts/x.py` and `python3 flake/scripts/x.py`
        # are one script; label it by its repo-relative path.
        script = ("flake/" if match.group(1) else "") + match.group(2)
        rest = (match.group(3) or "").split()
        if script in NEEDS_NIX:
            out.append((None, script, NEEDS_NIX[script]))
            continue
        if script in NEEDS_TOOL and not shutil.which(NEEDS_TOOL[script]):
            out.append((None, script, f"needs {NEEDS_TOOL[script]} on PATH "
                                      f"(dev shell); CI runs it"))
            continue
        argv = [sys.executable, script, *rest, *EXTRA_ARGS.get(script, [])]
        out.append((argv, script, None))
    return out


def clean_env():
    """The environment minus git's repository-locating variables.

    git exports GIT_DIR, GIT_INDEX_FILE and friends to hooks. A test that
    runs `git init` or `git commit` in a temp dir while inheriting them acts
    on the real repository: it rewrote its config and added commits to the
    branch being committed. `git rev-parse --local-env-vars` is git's own
    list of them.
    """
    out = subprocess.run(["git", "rev-parse", "--local-env-vars"],
                         capture_output=True, text=True).stdout.split()
    return {name: value for name, value in os.environ.items() if name not in out}


def run_one(argv):
    result = subprocess.run(argv, cwd=REPO, capture_output=True, text=True,
                       env=clean_env())
    return result.returncode, (result.stdout + result.stderr)


def cmd_preflight():
    steps = classify(preflight_lines())
    runnable = [(argv, step_label) for argv, step_label, _ in steps if argv]
    for _, label, reason in (step for step in steps if not step[0]):
        print(f"skip  {label}  -- {reason}")
    failed = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        futures = {pool.submit(run_one, argv): step_label for argv, step_label in runnable}
        for fut in concurrent.futures.as_completed(futures):
            label = futures[fut]
            rc, out = fut.result()
            print(f"{'ok  ' if rc == 0 else 'FAIL'}  {label}")
            if rc:
                failed.append((label, out))
    for label, out in failed:
        print(f"\n--- {label} (tail) ---", file=sys.stderr)
        print("\n".join(out.strip().splitlines()[-25:]), file=sys.stderr)
    print(f"\noffline preflight: {len(runnable) - len(failed)}/{len(runnable)} "
          f"ran clean, {len(steps) - len(runnable)} skipped (need nix); "
          f"CI runs those.")
    return 1 if failed else 0


def main():
    cmds = {"staged": cmd_staged, "preflight": cmd_preflight}
    if len(sys.argv) != 2 or sys.argv[1] not in cmds:
        print(__doc__)
        return 2
    return cmds[sys.argv[1]]()


if __name__ == "__main__":
    sys.exit(main())
