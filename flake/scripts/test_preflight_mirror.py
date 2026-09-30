#!/usr/bin/env python3
"""Fail when .github/workflows/check.yml stops running `just preflight`
itself, or starts running checks of its own beside it.

History, since the name no longer says it: until 2026-09-29 check.yml
listed preflight's steps a second time, by hand, and this script diffed
the two lists (a step on one side only was a failure an agent learned
about from a red PR). CI now runs `just preflight`, so there is one list
and nothing to diff. What can still go wrong is the copy growing back --
someone adds a check as a CI step instead of a preflight step, and the
agent's preflight is again testing a different checklist than the one
gating the PR. So this holds three things:

1. check.yml has a `run:` that invokes `just preflight`.
2. Every check a check.yml `run:` names (a .py/.sh script, or `nix flake
   check`) is either run by preflight too or listed in CI_ONLY below with
   its reason -- a new CI-only check has to be a deliberate edit here.
3. preflight names no undefined recipe, and still runs the anchor checks
   (a floor: the same check vanishing from preflight passes (1) and (2)).

How checks are identified: preflight is expanded (a `just <recipe>` line
pulls in that recipe's command lines, with {{scripts}}/{{flake}}/
{{user}} substituted), then each command line is reduced to the scripts
it runs, normalized to repo-relative paths so `cd flake && python3
scripts/lint.py check` and `flake/scripts/lint.py` land on the same key.
Setup steps (checkout, the nix installer, the sops warmup's `nix eval`)
extract no key. Step `name:` lines and comments are ignored.

Pure stdlib; runs via `just preflight-mirror-test`, part of `just
preflight` (and so of CI).
"""
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parents[2]
JUSTFILE = REPO / ".justfile"
WORKFLOW = REPO / ".github" / "workflows" / "check.yml"

SUBS = {"{{scripts}}": "flake/scripts", "{{flake}}": "flake",
        "{{user}}": "elly"}
HEADER = re.compile(r"^([A-Za-z][A-Za-z0-9_-]*)(?: [^:].*)?:\s*$")


def recipe_body(name, lines):
    """The indented body lines of a justfile recipe, as strings stripped of
    their indentation. Comments and blanks included; the caller filters."""
    body, in_recipe = [], False
    header = re.compile(rf"^{re.escape(name)}(?: [^:].*)?:\s*$")
    for line in lines:
        if in_recipe:
            if line.startswith((" ", "\t")):
                body.append(line.strip())
            elif line.strip() and not line.lstrip().startswith("#"):
                break  # the next unindented construct ends the recipe
        elif header.match(line):
            in_recipe = True
    return body


def expand(name, lines, depth=0):
    """preflight's command lines with `just <recipe>` lines replaced by the
    recipe's own command lines, recursively, and the {{...}} substitutions
    applied. Comment and shebang lines are not commands."""
    if depth > 10:
        sys.exit(f"preflight-mirror: recipe recursion deeper than 10 at "
                 f"'{name}' -- a cycle in the preflight recipe tree")
    out = []
    for raw in recipe_body(name, lines):
        line = raw.lstrip("@").strip()
        if not line or line.startswith("#") or line.startswith("#!"):
            continue
        for k, v in SUBS.items():
            line = line.replace(k, v)
        m = re.match(r"^just\s+([A-Za-z0-9_-]+)\s*$", line)
        if m:
            out += expand(m.group(1), lines, depth + 1)
            continue
        out.append(line)
    return out


# Checks check.yml may run that preflight does not, each with its reason.
CI_ONLY = {
    # Needs the PR's commit range, which only the pull_request event has;
    # its fixture test (test_check_trailers.py) is in preflight.
    "flake/scripts/check_trailers.py",
}


def keys_of(line):
    """The check-identity of one command line: every .py/.sh script it
    runs (as a repo-relative path -- `cd flake` makes `scripts/lint.py`
    and `flake/scripts/lint.py` the same file) plus a bare `nix flake
    check`."""
    keys = set()
    for m in re.finditer(r"[A-Za-z0-9_./-]+\.(?:py|sh)\b", line):
        p = m.group(0)
        keys.add("flake/" + p if p.startswith("scripts/") else p)
    if re.search(r"\bnix flake check\b", line):
        keys.add("nix flake check")
    return keys


def ci_run_lines(lines):
    """The command text of every `run:` in the workflow -- step `name:`
    lines deliberately cite script and recipe names in prose (e.g. the
    keybinding step is named after the file it runs) and must not count as
    checks, so only run values are returned: inline scalars directly, block
    scalars as their more-indented continuation lines."""
    out, block_indent = [], None
    for line in lines:
        if block_indent is not None:
            if not line.strip():
                continue
            if ((len(line) - len(line.lstrip())) > block_indent
                    and not line.lstrip().startswith("#")):
                out.append(line.strip())
            else:
                block_indent = None  # dedent: the block ended
            continue
        m = re.match(r"^\s*(?:-\s+)?run:\s*(.*)$", line)
        if m:
            rest = m.group(1).strip()
            if rest in ("|", "|-", ">", ">-", "|+", ">+"):
                block_indent = len(line) - len(line.lstrip())
            elif rest:
                out.append(rest)
            else:
                block_indent = len(line) - len(line.lstrip())
    return out


def main():
    justfile = JUSTFILE.read_text().splitlines()
    defined = {m.group(1) for line in justfile
               for m in [HEADER.match(line)] if m}

    referenced = [m.group(1)
                  for raw in recipe_body("preflight", justfile)
                  for m in [re.match(r"^@?just\s+([A-Za-z0-9_-]+)\s*$",
                                     raw.strip())] if m]
    unknown = sorted(set(referenced) - defined)
    if unknown:
        sys.exit(f"preflight-mirror: preflight calls recipe(s) {unknown} "
                 f"that .justfile does not define")

    preflight_keys = set().union(*(keys_of(l)
                                    for l in expand("preflight", justfile)))
    if not preflight_keys:
        sys.exit("preflight-mirror: preflight expanded to no recognizable "
                 "checks -- the justfile parser in this script has rotted")

    # Full-line comments carry the workflow's long explanation (and name
    # recipes and scripts in prose); only what actually runs counts.
    ci_lines = [l for l in WORKFLOW.read_text().splitlines()
                if not l.lstrip().startswith("#")]
    ci_runs = ci_run_lines(ci_lines)
    if not ci_runs:
        sys.exit("preflight-mirror: check.yml yielded no run: lines -- "
                 "the workflow parser in this script has rotted")
    if not any(re.search(r"\bjust\s+preflight\b", l) for l in ci_runs):
        sys.exit("preflight-mirror: check.yml no longer runs `just "
                 "preflight` -- CI would stop gating on the checklist "
                 "agents run locally")

    ci_keys = set().union(set(), *(keys_of(l) for l in ci_runs))
    strays = sorted(ci_keys - preflight_keys - CI_ONLY)
    if strays:
        print("check.yml runs checks that preflight does not:",
              file=sys.stderr)
        for k in strays:
            print(f"  {k}", file=sys.stderr)
        print("Add them to the preflight recipe instead (CI runs it), or, "
              "if one genuinely cannot run locally, to CI_ONLY in "
              "flake/scripts/test_preflight_mirror.py with the reason.",
              file=sys.stderr)
        sys.exit(1)

    # Floor anchors. `just preflight` being called proves nothing if
    # preflight itself quietly lost a check; these must stay in it.
    # Retiring one is a deliberate edit to this set.
    anchors = {
        "wiki/scripts/check_wiki.py",           # just wiki-lint
        "flake/scripts/modules.py",             # just modules
        "flake/scripts/lint.py",                # just lint
        "flake/scripts/test_guards.py",         # just guards-test
        "flake/scripts/flake-check.sh",         # just check
        "flake/scripts/test_check_trailers.py", # just trailers-test
    }
    missing = sorted(anchors - preflight_keys)
    if missing:
        sys.exit(
            "preflight-mirror: anchor check(s) no longer run by preflight "
            f"(and therefore by CI): {missing}. If one was deliberately "
            "retired, update `anchors` here in the same change -- this set "
            "is what keeps the check from passing vacuously.")
    print(f"preflight-mirror ok: CI runs `just preflight` ({len(preflight_keys)} "
          f"checks), plus {len(ci_keys & CI_ONLY)} CI-only")


if __name__ == "__main__":
    main()
