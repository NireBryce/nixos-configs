#!/usr/bin/env python3
"""Fail when .justfile's `preflight` recipe and .github/workflows/check.yml
stop running the same set of checks.

Both are hand-maintained copies of one checklist -- the steps an agent runs
before opening a PR, and the steps CI runs so a PR that skipped them still
fails. The preflight recipe's own comment names the failure mode of keeping
that copy by hand: a step added to one side and not the other is a failure
an agent only learns about from a red PR, minutes or days after they
reported their work green. Same motivation as check_wiki.py -- nothing
about the prose (here, the two check-lists) is read by anything that would
notice drift -- applied to CI instead of the wiki.

How the two sides are compared: preflight is expanded (a `just <recipe>`
line pulls in that recipe's command lines, with {{scripts}}/{{flake}}/
{{user}} substituted), then each side is reduced to the set of *checks* it
runs -- every referenced .py script, normalized to a repo-relative path so
`cd flake && python3 scripts/lint.py check` and `just lint` land on the
same key, plus `nix flake check` itself. CI-only steps that are setup, not
checks (checkout, the nix installer, the sops store-race warmup) extract no
key and are invisible to the comparison, as is anything the linter's
ratchet or a future check might wrap a script in. Set equality, not order:
preflight orders wiki-lint first because it fails in ~2s where `check`
spends minutes; CI orders it first so a broken wiki claim fails before the
toolchain installs. Both orderings are deliberate and neither is this
check's business. Also fails if preflight names a recipe .justfile doesn't
define -- a typo'd recipe name in the one recipe agents run most would
otherwise surface only as a just error at the worst moment.

Pure stdlib; runs via `just preflight-mirror-test`, part of `just
preflight` and CI. Note the test is itself on both check-lists -- adding
it to one side without the other fails here, which is the point.
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


def keys_of(line):
    """The check-identity of one command line: every .py script it runs
    (as a repo-relative path -- `cd flake` makes `scripts/lint.py` and
    `flake/scripts/lint.py` the same file) plus `nix flake check` itself."""
    keys = set()
    for m in re.finditer(r"[A-Za-z0-9_./-]+\.py\b", line):
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
    ci_keys = set().union(*(keys_of(l) for l in ci_run_lines(ci_lines)))
    if not ci_keys:
        sys.exit("preflight-mirror: check.yml yielded no recognizable "
                 "checks -- the workflow parser in this script has rotted")

    only_preflight = sorted(preflight_keys - ci_keys)
    only_ci = sorted(ci_keys - preflight_keys)
    if only_preflight or only_ci:
        print("preflight and CI check-lists have drifted:", file=sys.stderr)
        for k in only_preflight:
            print(f"  preflight only: {k}", file=sys.stderr)
        for k in only_ci:
            print(f"  CI only:        {k}", file=sys.stderr)
        print("Add the step to the other side in the same change -- an "
              "agent who runs only one of the two is testing a different "
              "checklist than the one that gates the PR.", file=sys.stderr)
        sys.exit(1)

    # Floor anchors. A two-sided mirror cannot see equal rot: the same
    # check disappearing from BOTH lists at once passes the set comparison
    # (demonstrated in review, 2026-09-29, by deleting lint.py from both
    # sides). These must be present on both sides no matter what else
    # changes; retiring one of them is a deliberate edit to this set, not
    # drift the script should stay quiet about.
    anchors = {
        "wiki/scripts/check_wiki.py",    # just wiki-lint
        "flake/scripts/modules.py",      # just modules
        "flake/scripts/lint.py",         # just lint
        "flake/scripts/test_guards.py",  # just guards-test
        "nix flake check",               # just check
    }
    missing = sorted(anchors - preflight_keys)
    if missing:
        sys.exit(
            "preflight-mirror: anchor check(s) no longer run by preflight "
            f"(and therefore, by the equality check above, by CI): "
            f"{missing}. If one was deliberately retired, update "
            "`anchors` here in the same change -- this set is what keeps "
            "the mirror from passing vacuously.")
    print(f"preflight/CI mirror ok: {len(preflight_keys)} checks on both "
          f"sides")


if __name__ == "__main__":
    main()
