#!/usr/bin/env python3
"""The mechanical half of skill `ship`: gate a PR, land it, commit safely.
The judgment half (which ask means what, the one combined question to the
user) stays in the skill; everything here is order and flags agents kept
re-typing -- the post-merge cleanup alone was a 31-session SEQUENCES row
in `just agent recurring` at 2026-09-29.

  ship.py ready <pr>       wait for CI, gate, print the summary to ask with
  ship.py land <pr>        gate again, merge, clean up; only after a yes
  ship.py commit [--agent NAME] [--] <path>...   message on stdin

Exit status: 0 done; 1 gate refused or a step failed (the message says
which, and `land` prints what is left to do); 2 usage.

The gate (both `ready` and `land`): state OPEN, not draft,
mergeStateStatus CLEAN, baseRefName experimental. `mergeable` is NOT the CI
answer, only "no conflicts": #413 (2026-09-28) read MERGEABLE with red CI
and mergeStateStatus BLOCKED, and the ask went out calling it mergeable.

Merge method from the commit count: one commit -> --rebase; more ->
--merge, because individual commit messages carry real reasoning and
squashing flattens it. `--match-head-commit` pins the merge to the commit
the gate read, so a push between the ask and the merge fails the merge
rather than landing something unseen.

`land` never passes `gh pr merge --delete-branch`: it removes only the
remote branch, and the flow also wants the local branch gone and
experimental current. After the merge it re-reads the PR and deletes
nothing unless state is MERGED. Then, in order, stopping at the first
failure and printing the steps left:

  - experimental: `git checkout experimental && git pull --ff-only` when no
    other worktree has it checked out. When one does (the usual case from a
    linked worktree, skill use-a-worktree: the shared checkout holds
    experimental), that checkout belongs to another session -- it is not
    pulled; this worktree is detached at the fetched origin/experimental
    instead, which frees the head branch for deletion.
  - local branch: `-D` when its tip is exactly the PR head GitHub merged
    (nothing local beyond what landed), else `-d`. Plain `-d` alone fails
    after every rebase merge once origin/<branch> is pruned: rebasing gives
    new SHAs, so git sees the branch as unmerged (the same reason `just
    branches` classifies by patch-id). A branch checked out in yet another
    worktree is left, with the command to finish it.
  - remote branch: `delete_branch_on_merge` is on, so it is normally
    already gone, and a bare `git push origin --delete` then fails with
    `failed to push some refs` (every ship since at least #416,
    2026-09-28). Deleted only if `git ls-remote --exit-code` still finds it.
  - `just close-fixed <pr>`: closing keywords in a PR body silently failed
    to close issues (#177, 2026-09-06); its own header has the detail.

`commit`: `git commit -F - -- <paths>`. An explicit pathspec is required
because `git commit`/`--amend` without one takes whatever is staged right
now -- hit twice 2026-08-30, sweeping up unrelated staged files. The
message comes on stdin because backticks and `$(...)` in an inline -m are
executed by the shell (2026-08-30: a backtick span became empty); feed it
through a quoted heredoc (`<<'EOF'`). Appends `Co-Authored-By: <agent>`
(default Claude; ZCode and opencode commit here too) unless a
Co-Authored-By trailer is already there -- and warns when that one carries
an email or model, which AGENTS.md's trailer rule forbids. Refuses to
commit on experimental or main: work lands there only through a PR.
"""
import argparse
import json
import os
import re
import shlex
import subprocess
import sys
import time

BASE = "experimental"
PROTECTED = {"experimental", "main"}
RETRY_SECONDS = float(os.environ.get("SHIP_RETRY_SECONDS", 3))  # tests: 0
FIELDS = ("url,title,state,isDraft,additions,deletions,changedFiles,"
          "mergeable,mergeStateStatus,baseRefName,headRefName,headRefOid,"
          "commits")

# What a non-CLEAN mergeStateStatus means for the next step.
STATUS_HINT = {
    "BLOCKED": "a required check is red or pending, or a ruleset blocks it"
               " (gh pr checks <pr>; red: gh run view <run> --log-failed)",
    "BEHIND": "the base moved; update the branch and re-run",
    "DIRTY": "merge conflicts with the base",
    "UNSTABLE": "a non-required check is failing",
    "HAS_HOOKS": "merge hooks pending",
    "DRAFT": "the PR is a draft",
    "UNKNOWN": "GitHub still hadn't computed it after several reads; re-run",
}


def run(cmd, **kw):
    return subprocess.run(cmd, text=True, **kw)


def out(cmd):
    """stdout of cmd, or None if it failed."""
    p = run(cmd, capture_output=True)
    return p.stdout.strip() if p.returncode == 0 else None


def say(msg=""):
    print(msg, flush=True)


# ---- gate ------------------------------------------------------------------

def view(pr, tries=6):
    """The PR's JSON. GitHub computes mergeStateStatus lazily: the first
    read after a while says UNKNOWN and the next, seconds later, the real
    answer (seen 2026-09-29 on #411: UNKNOWN, then CLEAN 3s on), so an
    UNKNOWN is re-read a few times before the gate sees it."""
    for i in range(tries):
        p = run(["gh", "pr", "view", pr, "--json", FIELDS], capture_output=True)
        if p.returncode != 0:
            sys.exit(f"gh pr view {pr} failed: {p.stderr.strip()}")
        d = json.loads(p.stdout)
        if d["state"] != "OPEN" or d["mergeStateStatus"] != "UNKNOWN":
            break
        if i < tries - 1:
            time.sleep(RETRY_SECONDS)
    return d


def gate_problems(d):
    probs = []
    if d["state"] != "OPEN":
        return [f"state is {d['state']}, not OPEN"]
    if d.get("isDraft"):
        probs.append("PR is a draft")
    st = d["mergeStateStatus"]
    if st != "CLEAN":
        hint = STATUS_HINT.get(st, "")
        probs.append(f"mergeStateStatus is {st}, not CLEAN"
                     + (f": {hint}" if hint else "")
                     + f" (mergeable={d['mergeable']} only means no conflicts)")
    if d["baseRefName"] != BASE:
        probs.append(f"base is {d['baseRefName']}, not {BASE}"
                     " (promotion to main is side-flows.md, not this)")
    return probs


def method(d):
    return "--rebase" if len(d["commits"]) == 1 else "--merge"


def summary(d):
    n = len(d["commits"])
    say(f"{d['title']}\n{d['url']}")
    say(f"{d['baseRefName']} <- {d['headRefName']}: +{d['additions']}"
        f" -{d['deletions']}, {d['changedFiles']} files, {n} commit"
        + ("" if n == 1 else "s"))
    for c in d["commits"]:
        say(f"  {c['oid'][:8]} {c['messageHeadline']}")
    say(f"merge method: {method(d)}"
        + (" (single commit)" if n == 1
           else " (several commits: keep each message)"))


def cmd_ready(a):
    checks = run(["gh", "pr", "checks", a.pr, "--watch", "--interval", "20"])
    d = view(a.pr)
    summary(d)
    probs = gate_problems(d)
    if checks.returncode != 0:
        probs.insert(0, f"gh pr checks exited {checks.returncode}")
    if probs:
        say("\nNOT READY -- don't ask to merge:")
        for p in probs:
            say(f"  - {p}")
        return 1
    say("\nREADY: ask the one combined question (merge, and delete the"
        " branch afterward?)")
    return 0


# ---- land ------------------------------------------------------------------

def worktrees():
    """{branch: path} for every worktree with a branch checked out."""
    wt, path = {}, None
    for line in (out(["git", "worktree", "list", "--porcelain"]) or "").splitlines():
        if line.startswith("worktree "):
            # realpath: show-toplevel and the porcelain list can disagree
            # on a symlinked prefix, and a mismatch reads as "elsewhere".
            path = os.path.realpath(line[len("worktree "):])
        elif line.startswith("branch refs/heads/"):
            wt[line[len("branch refs/heads/"):]] = path
    return wt


class Steps:
    """Run commands in order; on the first failure, print it and the rest."""

    def __init__(self):
        self.todo = []

    def add(self, cmd, check=None, note=None):
        self.todo.append((cmd, check, note))

    def run(self):
        while self.todo:
            cmd, check, note = self.todo.pop(0)
            if check and not check():
                continue
            say(f"$ {shlex.join(cmd)}")
            if run(cmd).returncode != 0:
                say(f"\nFAILED: {shlex.join(cmd)}\nstopped; left to do:")
                for rest, _, _ in self.todo:
                    say(f"  {shlex.join(rest)}")
                return False
            if note:
                say(note)
        return True


def cmd_land(a):
    d = view(a.pr)
    probs = gate_problems(d)
    if probs:
        say(f"refusing to merge #{a.pr}:")
        for p in probs:
            say(f"  - {p}")
        return 1
    head, oid, m = d["headRefName"], d["headRefOid"], method(d)
    local_tip = out(["git", "rev-parse", "--verify", "-q", f"refs/heads/{head}"])
    if local_tip and local_tip != oid:
        say(f"note: local {head} is at {local_tip[:8]}, the PR head is"
            f" {oid[:8]}; merging the PR head")

    merge = ["gh", "pr", "merge", a.pr, m, "--match-head-commit", oid]
    say(f"$ {shlex.join(merge)}")
    if run(merge).returncode != 0:
        say(f"\nmerge FAILED; nothing deleted. #{a.pr} is still open"
            " -- raise it, don't retry silently.")
        return 1
    state = out(["gh", "pr", "view", a.pr, "--json", "state", "-q", ".state"])
    if state != "MERGED":
        say(f"\n#{a.pr} reports state {state}, not MERGED; nothing deleted.")
        return 1
    say(f"merged #{a.pr} ({m})")

    here = os.path.realpath(out(["git", "rev-parse", "--show-toplevel"]))
    # The main checkout is shared by other sessions and can't be removed
    # like a linked worktree, so it is never detached (PR #435 review).
    is_main = (out(["git", "rev-parse", "--path-format=absolute", "--git-dir"])
               == out(["git", "rev-parse", "--path-format=absolute",
                       "--git-common-dir"]))
    wt = worktrees()
    exp_at = wt.get(BASE)
    s = Steps()
    s.add(["git", "fetch", "origin"])
    if exp_at in (None, here):
        if exp_at is None:
            s.add(["git", "checkout", BASE])
        s.add(["git", "pull", "--ff-only"])
    else:
        say(f"note: {BASE} is checked out at {exp_at}, another checkout;"
            " not pulled there.")
        if wt.get(head) == here and is_main:
            say(f"note: {head} is checked out here, in the main checkout;"
                " left as is rather than detaching a shared checkout.")
        elif wt.get(head) == here:
            s.add(["git", "checkout", "--detach", f"origin/{BASE}"],
                  note=f"note: this worktree is now detached at origin/{BASE};"
                       f" remove it when done: git worktree remove {here}")
    if not s.run():
        return 1

    # Re-read: the checkout/detach above may have freed the branch.
    held = worktrees().get(head)
    tip = out(["git", "rev-parse", "--verify", "-q", f"refs/heads/{head}"])
    if held and is_main and held == here:
        say(f"note: {head} is checked out here, in the main checkout; left."
            f" To finish: move this checkout off {head} ({BASE} is checked"
            f" out at {exp_at}), then git branch -D {head}")
    elif held:
        say(f"note: {head} is checked out at {held}; left. To finish:"
            f" git worktree remove {held} && git branch -D {head}")
    elif tip:
        s.add(["git", "branch", "-D" if tip == oid else "-d", head])
    s.add(["git", "push", "origin", "--delete", head],
          check=lambda: run(["git", "ls-remote", "--exit-code", "--heads",
                             "origin", head], capture_output=True).returncode == 0)
    s.add(["just", "close-fixed", a.pr])
    return 0 if s.run() else 1


# ---- commit ----------------------------------------------------------------

TRAILER = re.compile(r"(?im)^co-authored-by:(.*)$")


def with_trailer(msg, agent):
    """msg plus `Co-Authored-By: agent`, unless it already has one."""
    msg = msg.rstrip() + "\n"
    if TRAILER.search(msg):
        return msg
    last = msg.rstrip("\n").split("\n\n")[-1].splitlines()
    in_block = len(msg.split("\n\n")) > 1 and all(
        re.match(r"^[A-Za-z][A-Za-z0-9-]*: ", l) for l in last)
    return msg + ("" if in_block else "\n") + f"Co-Authored-By: {agent}\n"


def cmd_commit(a):
    paths = [p for p in a.paths if p != "--"]
    if not paths:
        sys.exit("usage: commit [--agent NAME] [--] <path>...  (message on"
                 " stdin; at least one path -- a bare commit takes whatever"
                 " is staged)")
    branch = out(["git", "branch", "--show-current"])
    if branch is None:
        sys.exit("not in a git repository")
    if branch == "":
        # A detached HEAD's commit belongs to no branch -- e.g. a worktree
        # ship-land left detached at origin/experimental (PR #435 review).
        sys.exit("refusing to commit on a detached HEAD: branch first"
                 " (git switch -c <feat/...>)")
    if branch in PROTECTED:
        sys.exit(f"refusing to commit on {branch}: branch first"
                 " (git switch -c <feat/...>); it lands through a PR")
    if sys.stdin.isatty():
        sys.exit("message goes on stdin: ... commit -- <paths> <<'EOF'")
    msg = sys.stdin.read()
    if not msg.strip():
        sys.exit("empty commit message on stdin")
    msg = with_trailer(msg, a.agent)
    for m in TRAILER.finditer(msg):
        if "<" in m.group(1) or "@" in m.group(1) or len(m.group(1).split()) > 1:
            print(f"warning: trailer `{m.group(0).strip()}` -- AGENTS.md wants"
                  " the agent name only, no model or email", file=sys.stderr)
    return run(["git", "commit", "-F", "-", "--", *paths], input=msg).returncode


def main(argv=None):
    ap = argparse.ArgumentParser(prog="ship.py", description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name, fn in (("ready", cmd_ready), ("land", cmd_land)):
        p = sub.add_parser(name)
        p.add_argument("pr")
        p.set_defaults(fn=fn)
    p = sub.add_parser("commit")
    p.add_argument("--agent", default="Claude")
    p.add_argument("paths", nargs=argparse.REMAINDER)
    p.set_defaults(fn=cmd_commit)
    a = ap.parse_args(argv)
    return a.fn(a)


if __name__ == "__main__":
    sys.exit(main())
