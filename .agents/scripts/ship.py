#!/usr/bin/env python3
"""The mechanical half of skill `ship`: gate a PR, land it, commit safely.
The judgment half (which ask means what, the one combined question to the
user) stays in the skill; everything here is order and flags agents kept
re-typing -- the post-merge cleanup alone was a 31-session SEQUENCES row
in `just agent recurring` at 2026-09-29.

  ship.py ready <pr>       wait for CI, gate, print the summary to ask with
  ship.py land <pr>        gate again, merge, clean up; only after a yes
  ship.py commit [--agent NAME] [--] <path>...   message on stdin
  ship.py pr <body-file> [--title T]     push if needed, open the PR
  ship.py pr <body-file> --edit <n> [--title T]   replace a PR's body

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
    That check can still race GitHub's delete (ls-remote sees the branch,
    the delete then finds it gone): a failed delete is re-checked with
    ls-remote, and a branch now absent counts as done.
  - `just close-fixed <pr>`: closing keywords in a PR body silently failed
    to close issues (#177, 2026-09-06); its own header has the detail.

`commit`: `git commit -F - -- <paths>`. An explicit pathspec is required
because `git commit`/`--amend` without one takes whatever is staged right
now -- hit twice 2026-08-30, sweeping up unrelated staged files. The
message comes on stdin because backticks and `$(...)` in an inline -m are
executed by the shell (2026-08-30: a backtick span became empty); feed it
through a quoted heredoc (`<<'EOF'`). Appends `Co-Authored-By: <agent>`
(default Claude; other harnesses commit here too) unless a
Co-Authored-By trailer is already there -- and warns when that one carries
an email or model, which AGENTS.md's trailer rule forbids. Refuses to
commit on experimental or main: work lands there only through a PR.

`pr`: `gh pr create --base experimental --head <branch> --body-file F`
for the current branch, after `git push -u origin <branch>` when its
upstream isn't origin/<branch> (a branch cut from origin/experimental
tracks the trunk, and a plain push from there is refused) (plain `git push` when it is ahead of one: gh asks where to
push otherwise, and an agent has no terminal to answer). The title
defaults to the only commit's subject; several commits need --title.
Refuses on experimental, main, or a detached HEAD, and refuses a body
missing the LLM-disclosure line (`🤖 Co-written by an LLM agent`, skill
ship) before the first `## ` heading or as its last line --
.github/PULL_REQUEST_TEMPLATE.md asks for it at both ends (a harness
footer, `🤖 Generated with ...`, counts at the bottom). The body goes in
a file because backticks in an inline --body are executed by the shell.
`--edit <n>`: `gh pr edit <n> --body-file F` (and --title), same check.
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
          "isCrossRepository,commits")

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
    completed = run(cmd, capture_output=True)
    return completed.stdout.strip() if completed.returncode == 0 else None


def say(msg=""):
    print(msg, flush=True)


# ---- gate ------------------------------------------------------------------

def view(pr, tries=6):
    """The PR's JSON. GitHub computes mergeStateStatus lazily: the first
    read after a while says UNKNOWN and the next, seconds later, the real
    answer (seen 2026-09-29 on #411: UNKNOWN, then CLEAN 3s on), so an
    UNKNOWN is re-read a few times before the gate sees it."""
    for attempt in range(tries):
        completed = run(["gh", "pr", "view", pr, "--json", FIELDS], capture_output=True)
        if completed.returncode != 0:
            sys.exit(f"gh pr view {pr} failed: {completed.stderr.strip()}")
        pr_data = json.loads(completed.stdout)
        if pr_data["state"] != "OPEN" or pr_data["mergeStateStatus"] != "UNKNOWN":
            break
        if attempt < tries - 1:
            time.sleep(RETRY_SECONDS)
    return pr_data


def gate_problems(pr_data):
    probs = []
    if pr_data["state"] != "OPEN":
        return [f"state is {pr_data['state']}, not OPEN"]
    if pr_data.get("isDraft"):
        probs.append("PR is a draft")
    merge_state = pr_data["mergeStateStatus"]
    if merge_state != "CLEAN":
        hint = STATUS_HINT.get(merge_state, "")
        probs.append(f"mergeStateStatus is {merge_state}, not CLEAN"
                     + (f": {hint}" if hint else "")
                     + f" (mergeable={pr_data['mergeable']} only means no conflicts)")
    # land deletes the PR's head branch by name, so the head has to be this
    # repo's own topic branch: a fork PR (or a missing field, which reads as
    # one) or a head named like a protected branch or like the base would
    # point that delete at a branch that is not the PR's.
    if pr_data.get("isCrossRepository", True):
        probs.append("the head is in another repository (or that could not"
                     " be told); landing it would delete a branch by name")
    head = pr_data.get("headRefName")
    if head in PROTECTED or head == "master" or head == pr_data["baseRefName"]:
        probs.append(f"the head branch {head!r} is protected or the same as"
                     " the base; refusing to merge and delete it")
    if pr_data["baseRefName"] != BASE:
        probs.append(f"base is {pr_data['baseRefName']}, not {BASE}"
                     " (promotion to main is side-flows.md, not this)")
    return probs


def method(pr_data):
    return "--rebase" if len(pr_data["commits"]) == 1 else "--merge"


def summary(pr_data):
    commit_count = len(pr_data["commits"])
    say(f"{pr_data['title']}\n{pr_data['url']}")
    say(f"{pr_data['baseRefName']} <- {pr_data['headRefName']}: +{pr_data['additions']}"
        f" -{pr_data['deletions']}, {pr_data['changedFiles']} files, {commit_count} commit"
        + ("" if commit_count == 1 else "s"))
    for commit in pr_data["commits"]:
        say(f"  {commit['oid'][:8]} {commit['messageHeadline']}")
    say(f"merge method: {method(pr_data)}"
        + (" (single commit)" if commit_count == 1
           else " (several commits: keep each message)"))


def cmd_ready(args):
    checks = run(["gh", "pr", "checks", args.pr, "--watch", "--interval", "20"])
    pr_data = view(args.pr)
    summary(pr_data)
    probs = gate_problems(pr_data)
    if checks.returncode != 0:
        probs.insert(0, f"gh pr checks exited {checks.returncode}")
    if probs:
        say("\nNOT READY -- don't ask to merge:")
        for problem in probs:
            say(f"  - {problem}")
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
    """Run commands in order; on the first failure, print it and the rest.
    `check` false skips a step; `settled` true after a failure means the
    step's goal holds anyway, so the run goes on."""

    def __init__(self):
        self.todo = []

    def add(self, cmd, check=None, note=None, settled=None):
        self.todo.append((cmd, check, note, settled))

    def run(self):
        while self.todo:
            cmd, check, note, settled = self.todo.pop(0)
            if check and not check():
                continue
            say(f"$ {shlex.join(cmd)}")
            if run(cmd).returncode != 0:
                if settled and settled():
                    say("note: failed, but its goal already holds; going on")
                    continue
                say(f"\nFAILED: {shlex.join(cmd)}\nstopped; left to do:")
                for rest, *_ in self.todo:
                    say(f"  {shlex.join(rest)}")
                return False
            if note:
                say(note)
        return True


def cmd_land(args):
    pr_data = view(args.pr)
    probs = gate_problems(pr_data)
    if probs:
        say(f"refusing to merge #{args.pr}:")
        for problem in probs:
            say(f"  - {problem}")
        return 1
    head, oid, merge_method = pr_data["headRefName"], pr_data["headRefOid"], method(pr_data)
    local_tip = out(["git", "rev-parse", "--verify", "-q", f"refs/heads/{head}"])
    if local_tip and local_tip != oid:
        say(f"note: local {head} is at {local_tip[:8]}, the PR head is"
            f" {oid[:8]}; merging the PR head")

    merge = ["gh", "pr", "merge", args.pr, merge_method, "--match-head-commit", oid]
    say(f"$ {shlex.join(merge)}")
    if run(merge).returncode != 0:
        say(f"\nmerge FAILED; nothing deleted. #{args.pr} is still open"
            " -- raise it, don't retry silently.")
        return 1
    state = out(["gh", "pr", "view", args.pr, "--json", "state", "-q", ".state"])
    if state != "MERGED":
        say(f"\n#{args.pr} reports state {state}, not MERGED; nothing deleted.")
        return 1
    say(f"merged #{args.pr} ({merge_method})")

    here = os.path.realpath(out(["git", "rev-parse", "--show-toplevel"]))
    # The main checkout is shared by other sessions and can't be removed
    # like a linked worktree, so it is never detached (PR #435 review).
    is_main = (out(["git", "rev-parse", "--path-format=absolute", "--git-dir"])
               == out(["git", "rev-parse", "--path-format=absolute",
                       "--git-common-dir"]))
    wt = worktrees()
    exp_at = wt.get(BASE)
    steps = Steps()
    steps.add(["git", "fetch", "origin"])
    if exp_at in (None, here):
        if exp_at is None:
            steps.add(["git", "checkout", BASE])
        steps.add(["git", "pull", "--ff-only"])
    else:
        say(f"note: {BASE} is checked out at {exp_at}, another checkout;"
            " not pulled there.")
        if wt.get(head) == here and is_main:
            say(f"note: {head} is checked out here, in the main checkout;"
                " left as is rather than detaching a shared checkout.")
        elif wt.get(head) == here:
            steps.add(["git", "checkout", "--detach", f"origin/{BASE}"],
                  note=f"note: this worktree is now detached at origin/{BASE};"
                       f" remove it when done: git worktree remove {here}")
    if not steps.run():
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
        steps.add(["git", "branch", "-D" if tip == oid else "-d", head])
    def on_remote():
        return run(["git", "ls-remote", "--exit-code", "--heads", "origin",
                    head], capture_output=True).returncode == 0
    # settled: GitHub's delete-on-merge can land between the ls-remote and
    # the delete; the branch being gone is the step's goal either way.
    steps.add(["git", "push", "origin", "--delete", head], check=on_remote,
          settled=lambda: not on_remote())
    steps.add(["just", "close-fixed", args.pr])
    return 0 if steps.run() else 1


# ---- commit ----------------------------------------------------------------

TRAILER = re.compile(r"(?im)^co-authored-by:(.*)$")


def with_trailer(msg, agent):
    """msg plus `Co-Authored-By: agent`, unless it already has one."""
    msg = msg.rstrip() + "\n"
    if TRAILER.search(msg):
        return msg
    last = msg.rstrip("\n").split("\n\n")[-1].splitlines()
    in_block = len(msg.split("\n\n")) > 1 and all(
        re.match(r"^[A-Za-z][A-Za-z0-9-]*: ", line) for line in last)
    return msg + ("" if in_block else "\n") + f"Co-Authored-By: {agent}\n"


def cmd_commit(args):
    paths = [path for path in args.paths if path != "--"]
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
    msg = with_trailer(msg, args.agent)
    for trailer_match in TRAILER.finditer(msg):
        if "<" in trailer_match.group(1) or "@" in trailer_match.group(1) or len(trailer_match.group(1).split()) > 1:
            print(f"warning: trailer `{trailer_match.group(0).strip()}` -- AGENTS.md wants"
                  " the agent name only, no model or email", file=sys.stderr)
    changed = [path for path in paths if type_changed(path)]
    if changed:
        sys.exit(
            f"refusing: {', '.join(changed)} changed type (file/symlink <-> "
            "directory) since HEAD, which `git commit -- <path>` either rejects "
            "or commits only partly. Stage it yourself (`git add -A -- <path>`), "
            "check `git diff --cached --name-only` lists only what you mean, "
            "then `git commit -F <msgfile>` with the trailer in the message.")
    return run(["git", "commit", "-F", "-", "--", *paths], input=msg).returncode


def type_changed(path):
    """True when `path` is a directory in the work tree but a file or symlink
    in HEAD, or a file or symlink in the work tree but a directory in HEAD.
    Relative to the cwd, like the pathspec itself. A trailing slash is
    dropped first: `ls-tree HEAD -- d/` lists d's contents, not d."""
    path = path.rstrip("/") or path
    entry = out(["git", "ls-tree", "HEAD", "--", path]) or ""
    kind = entry.split(" ", 2)[1:2]
    if not kind or not os.path.lexists(path):
        return False
    is_dir = os.path.isdir(path) and not os.path.islink(path)
    return (kind == ["blob"] and is_dir) or (kind == ["tree"] and not is_dir)


# ---- pr --------------------------------------------------------------------

DISCLOSURE = re.compile(r"^\s*🤖 Co-written by an LLM agent")
FOOTER = re.compile(r"^\s*🤖 (Co-written by an LLM agent|Generated with )")


def disclosure_problems(body):
    """What the body lacks of the template's top-and-bottom disclosure."""
    text = re.sub(r"<!--.*?-->", "", body, flags=re.S)
    lines = [line for line in text.splitlines() if line.strip()]
    head = []
    for line in lines:
        if line.startswith("## "):
            break
        head.append(line)
    probs = []
    if not any(DISCLOSURE.match(line) for line in head):
        probs.append("no `🤖 Co-written by an LLM agent` line before the"
                     " first `## ` heading")
    if not lines or not FOOTER.match(lines[-1]):
        probs.append("last line is not the disclosure (`🤖 Co-written by an"
                     " LLM agent`, or a harness `🤖 Generated with ...` footer)")
    return probs


def cmd_pr(args):
    try:
        body = open(args.body_file, encoding="utf-8").read()
    except OSError as error:
        sys.exit(f"can't read body file: {error}")
    probs = disclosure_problems(body)
    if probs:
        say(f"refusing: {args.body_file} lacks the LLM disclosure"
            " .github/PULL_REQUEST_TEMPLATE.md asks for at top and bottom:")
        for problem in probs:
            say(f"  - {problem}")
        return 1
    if args.edit:
        cmd = ["gh", "pr", "edit", args.edit, "--body-file", args.body_file]
        if args.title:
            cmd += ["--title", args.title]
        say(f"$ {shlex.join(cmd)}")
        return run(cmd).returncode

    branch = out(["git", "branch", "--show-current"])
    if branch is None:
        sys.exit("not in a git repository")
    if branch == "":
        sys.exit("refusing on a detached HEAD: a PR needs a branch")
    if branch in PROTECTED:
        sys.exit(f"refusing on {branch}: branch first (git switch -c"
                 " <feat/...>); a PR is opened from a topic branch")
    run(["git", "fetch", "-q", "origin"])
    subjects = (out(["git", "log", "--format=%s", f"origin/{BASE}..HEAD"])
                or "").splitlines()
    if not subjects:
        sys.exit(f"refusing: {branch} has no commits ahead of origin/{BASE}")
    title = args.title
    if not title:
        if len(subjects) > 1:
            sys.exit(f"{len(subjects)} commits ahead of origin/{BASE}:"
                     " pass --title")
        title = subjects[0]
    # An upstream other than origin/<branch> counts as none: `git switch
    # -c x origin/experimental` (and worktree add -b) tracks the trunk,
    # and a plain push there is refused (or worse, aimed at it).
    if out(["git", "rev-parse", "--abbrev-ref", "--symbolic-full-name",
            "@{u}"]) != f"origin/{branch}":
        push = ["git", "push", "-u", "origin", branch]
    elif out(["git", "rev-list", "--count", "@{u}..HEAD"]) not in ("0", None):
        push = ["git", "push"]
    else:
        push = None
    if push:
        say(f"$ {shlex.join(push)}")
        if run(push).returncode != 0:
            say("push FAILED; no PR opened")
            return 1
    cmd = ["gh", "pr", "create", "--base", BASE, "--head", branch,
           "--title", title, "--body-file", args.body_file]
    say(f"$ {shlex.join(cmd)}")
    return run(cmd).returncode


def main(argv=None):
    ap = argparse.ArgumentParser(prog="ship.py", description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name, fn in (("ready", cmd_ready), ("land", cmd_land)):
        subparser = sub.add_parser(name)
        subparser.add_argument("pr")
        subparser.set_defaults(fn=fn)
    subparser = sub.add_parser("commit")
    subparser.add_argument("--agent", default="Claude")
    subparser.add_argument("paths", nargs=argparse.REMAINDER)
    subparser.set_defaults(fn=cmd_commit)
    subparser = sub.add_parser("pr")
    subparser.add_argument("body_file")
    subparser.add_argument("--title")
    subparser.add_argument("--edit", metavar="N")
    subparser.set_defaults(fn=cmd_pr)
    args = ap.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
