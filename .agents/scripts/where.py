#!/usr/bin/env python3
"""Where is this checkout, relative to origin/experimental and its PR?

Replaces the orientation runs `just agent recurring` ranked highest at
2026-10-03: `git fetch -> git status -sb` (53 sessions), `git log
--oneline <range> -> git diff --stat <range>` (50), `gh pr view <n> --json
... -> log -> diff --stat` (30), `git log --oneline -N <-> git status -sb`
(47). One call, fixed order:

  1. `git fetch -q origin`. Offline or failing: says so and continues on
     the cached remote-tracking refs (the rest is still worth reading).
  2. `git status -sb`'s first line (branch, upstream, ahead/behind), then
     the dirty path count and up to DIRTY_CAP of them.
  3. ahead/behind origin/experimental, and the commits ahead
     (`git log --oneline origin/experimental..HEAD`, up to LOG_CAP).
  4. `git diff --stat origin/experimental...HEAD`'s summary line: what a
     PR from here would change (three dots: since the merge base).
  5. The PR: with <pr>, that one; without, the open PR for this branch
     (`gh pr view --json number,title,state,mergeStateStatus,url`). No gh,
     offline, no PR, on experimental/main or detached: one line saying
     which.

Read-only: fetch updates remote-tracking refs and nothing else; no
checkout, no branch or worktree change. Exit 0 whenever it could report;
2 outside a git repo. Ship's gate stays `just agent ship-ready` -- a
mergeStateStatus here is a glance, not the gate.

    where.py [<pr>]
"""
import json
import os
import subprocess
import sys

BASE = "origin/experimental"
TRUNKS = {"experimental", "main"}
DIRTY_CAP = 15
LOG_CAP = 20
PR_FIELDS = "number,title,state,mergeStateStatus,url,headRefName,baseRefName"
ENV = {**os.environ, "GIT_TERMINAL_PROMPT": "0",
       "GIT_SSH_COMMAND": os.environ.get(
           "GIT_SSH_COMMAND", "ssh -o BatchMode=yes -o ConnectTimeout=8")}


def run(cmd, timeout=30):
    """(returncode, stdout, stderr); a missing program or a timeout is a
    failed result, never a traceback."""
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, env=ENV,
                           timeout=timeout)
        return p.returncode, p.stdout.rstrip("\n"), p.stderr.strip()
    except FileNotFoundError:
        return 127, "", f"{cmd[0]}: not on PATH"
    except subprocess.TimeoutExpired:
        return 124, "", f"timed out after {timeout}s"


def git(*args):
    rc, out, _ = run(["git", *args])
    return out if rc == 0 else None


def first_line(text):
    return (text.splitlines() or [""])[0][:160]


def fetch():
    rc, _, err = run(["git", "fetch", "-q", "origin"], timeout=30)
    if rc == 0:
        return "fetch: origin ok"
    return (f"fetch: FAILED ({first_line(err) or f'exit {rc}'}); "
            "offline? continuing with cached refs")


def capped(lines, cap, indent="  "):
    out = [indent + line for line in lines[:cap]]
    if len(lines) > cap:
        out.append(f"{indent}... {len(lines) - cap} more")
    return out


def local_state():
    out = []
    status = git("status", "-sb", "--porcelain=v1") or ""
    lines = status.splitlines()
    out.append(lines[0] if lines else "## (no status)")
    dirty = lines[1:]
    out.append(f"dirty: {len(dirty)} path{'' if len(dirty) == 1 else 's'}")
    out += capped(dirty, DIRTY_CAP)

    if git("rev-parse", "-q", "--verify", f"{BASE}^{{commit}}") is None:
        out.append(f"{BASE}: no such ref (no origin, or never fetched)")
        return out
    counts = (git("rev-list", "--left-right", "--count", f"{BASE}...HEAD")
              or "? ?").split()
    behind, ahead = (counts + ["?", "?"])[:2]
    out.append(f"vs {BASE}: ahead {ahead}, behind {behind}")
    log = (git("log", "--oneline", "--no-decorate", f"{BASE}..HEAD") or "").splitlines()
    out += capped(log, LOG_CAP)
    stat = (git("diff", "--stat", f"{BASE}...HEAD") or "").splitlines()
    out.append(f"diff --stat {BASE}...HEAD: "
               + (stat[-1].strip() if stat else "no changes"))
    return out


def pr_line(pr, branch):
    if pr is None:
        if not branch:
            return "PR: none looked up (detached HEAD)"
        if branch in TRUNKS:
            return f"PR: none looked up (on {branch})"
    rc, out, err = run(["gh", "pr", "view", *([pr] if pr else []),
                        "--json", PR_FIELDS], timeout=20)
    if rc == 0:
        try:
            d = json.loads(out)
            return (f"PR: #{d.get('number')} {d.get('state')} "
                    f"{d.get('mergeStateStatus')} {d.get('baseRefName')} <- "
                    f"{d.get('headRefName')}\n  {d.get('title')}\n  {d.get('url')}")
        except (ValueError, AttributeError):
            return "PR: gh answered with something other than JSON"
    if rc == 127:
        return "PR: gh not on PATH; not looked up"
    if "no pull requests found" in err.lower():
        return f"PR: none for {branch}"
    return f"PR: lookup failed ({first_line(err) or f'exit {rc}'})"


def main(argv):
    if len(argv) > 1 or (argv and argv[0].startswith("-")):
        print(__doc__.strip().splitlines()[-1].strip(), file=sys.stderr)
        return 2
    pr = argv[0] if argv else None
    if git("rev-parse", "--is-inside-work-tree") != "true":
        print("where: not inside a git work tree", file=sys.stderr)
        return 2
    branch = git("branch", "--show-current") or ""
    print(fetch())
    for line in local_state():
        print(line)
    print(pr_line(pr, branch))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
