#!/usr/bin/env python3
"""Create and clean up the per-task worktrees skill `use-a-worktree` asks
for, so neither step is hand-assembled: the create is a fetch plus a
`worktree add -b` agents re-type every session, and the cleanup is the
part nobody did -- worktrees outlive their PRs because `ship-land` leaves
a linked worktree detached (it can't remove the directory it runs in).

  worktree.py new <branch> [<base>] [--root DIR]
  worktree.py prune [--yes] [--root DIR] [--min-age MIN] [--depth N]

ROOT is where agent worktrees live: --root, else $AGENT_SCRATCH, else
/tmp (the skill's convention: the harness scratchpad when the system
prompt names one -- pass it as --root -- otherwise /tmp).

`new`: `git fetch origin`, then `git worktree add ROOT/wt-<name> -b
<branch> <base>` (base default origin/experimental), where <name> is the
branch minus its first `feat/`-style component, remaining `/` as `-`.
Prints only the absolute path, so `cd "$(... new feat/x)"` works. Refuses
when the branch exists (locally or on origin) or the path does.

`prune`: every linked worktree of this repo whose path is under ROOT --
never the main checkout, never anything outside ROOT, never the worktree
it runs in, never a locked one. One line each: clean/dirty, branch (or
detached), how far ahead of origin/experimental it is and whether those
commits landed there (patch-id, `flake/scripts/branches.py`'s functions,
so rebased merges count), and whether origin still has the branch.
Removable when clean AND one of:
  - landed: >= 1 commit ahead, every non-merge one's patch-id already in
    origin/experimental; or 0 ahead and gh records the branch's PR MERGED
    (a --merge landing, branches.py's #334 case); or detached and 0 ahead
    (what ship-land leaves behind);
  - fresh: 0 ahead, never pushed, and untouched for --min-age minutes
    (default 60). The age guard is branches.py's #300 window: another
    session's brand-new worktree looks exactly like an abandoned one until
    its first commit.
Without --yes it prints what it would do and deletes nothing. With --yes:
`git worktree remove` (no --force -- git's own dirty check is the
backstop for this script's), then `git branch -D` on its branch. -D, not
-d, for the reason branches.py gives: -d judges "merged" against HEAD or
the upstream, which is arbitrary from wherever this runs and refuses every
rebase-landed branch; the verdict above is the safety check. A dirty
worktree is never removed. Exit: 0; 1 on a refusal or a failed removal;
2 on usage.
"""
import argparse
import os
import re
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "flake" / "scripts"))
import branches  # noqa: E402  patch_id, trunk_patch_ids, pr_merged

BASE = "origin/experimental"
PROTECTED = {"main", "master", "experimental"}


def git(*args, cwd=None, check=True):
    result = subprocess.run(["git", *([] if cwd is None else ["-C", str(cwd)]), *args],
                       capture_output=True, text=True)
    if check and result.returncode != 0:
        sys.exit(f"git {' '.join(args)} failed:\n{result.stderr.strip()}")
    return result.stdout.strip() if check else result


def root_of(args):
    root_arg = args.root or os.environ.get("AGENT_SCRATCH") or "/tmp"
    return Path(os.path.realpath(root_arg))


def dir_name(branch):
    rest = branch.split("/", 1)[1] if "/" in branch else branch
    return "wt-" + rest.replace("/", "-")


def fetch():
    result = subprocess.run(["git", "fetch", "-q", "--prune", "origin"],
                       capture_output=True, text=True)
    if result.returncode != 0:
        print(f"warning: git fetch origin failed: {result.stderr.strip()}",
              file=sys.stderr)


def cmd_new(args):
    root = root_of(args)
    path = root / dir_name(args.branch)
    if not re.fullmatch(r"[A-Za-z0-9._/-]+", args.branch) or git(
            "check-ref-format", "--branch", args.branch, check=False).returncode:
        sys.exit(f"refusing: {args.branch!r} is not a usable branch name")
    fetch()
    for ref in (f"refs/heads/{args.branch}", f"refs/remotes/origin/{args.branch}"):
        if git("rev-parse", "-q", "--verify", ref, check=False).returncode == 0:
            sys.exit(f"refusing: {ref} already exists")
    if path.exists() or path.is_symlink():
        sys.exit(f"refusing: {path} already exists")
    root.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(["git", "worktree", "add", "-q", str(path), "-b",
                        args.branch, args.base], capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(f"git worktree add failed:\n{result.stderr.strip()}")
    print(path)
    return 0


# ---- prune -------------------------------------------------------------

def linked_worktrees():
    """[{path, branch|None, locked, prunable, admin}] for linked worktrees."""
    rows, cur = [], None
    for line in git("worktree", "list", "--porcelain").splitlines() + [""]:
        if line.startswith("worktree "):
            cur = dict(path=line[9:], branch=None, locked=False, prunable=False)
        elif cur is None:
            continue
        elif line.startswith("branch refs/heads/"):
            cur["branch"] = line[len("branch refs/heads/"):]
        elif line.startswith("locked"):
            cur["locked"] = True
        elif line.startswith("prunable"):
            cur["prunable"] = True
        elif line == "":
            rows.append(cur)
            cur = None
    return rows[1:]  # the first entry is always the main checkout


def age_minutes(path):
    """Minutes since the worktree's HEAD/index last changed."""
    gitdir = git("rev-parse", "--absolute-git-dir", cwd=path)
    times = [os.path.getmtime(head_or_index) for head_or_index in (Path(gitdir) / "HEAD",
                                           Path(gitdir) / "index") if head_or_index.exists()]
    return (time.time() - max(times)) / 60 if times else 0


class Landed:
    """Patch-ids of origin/experimental, computed once and only if asked."""

    def __init__(self, depth):
        self.depth, self.ids = depth, None

    def check(self, commits):
        if self.ids is None:
            branches.TRUNK = BASE
            self.ids = branches.trunk_patch_ids(self.depth)
        pids = [branches.patch_id(commit) for commit in commits]
        readable = [patch for patch in pids if patch]
        return bool(readable) and all(patch in self.ids for patch in readable)


def verdict(worktree, landed, min_age):
    """-> (removable, description)."""
    path, branch = worktree["path"], worktree["branch"]
    if branch in PROTECTED:
        # prune deletes the branch with -D after removing the worktree, and
        # "PR merged" is looked up by head name, which promotion PRs share.
        return False, f"protected branch {branch}; never pruned"
    dirty = bool(git("status", "--porcelain", cwd=path))
    ahead = git("rev-list", f"{BASE}..HEAD", cwd=path).split()
    pushed = branch is not None and git("rev-parse", "-q", "--verify",
                                   f"refs/remotes/origin/{branch}",
                                   check=False).returncode == 0
    if ahead:
        why = "landed" if landed.check(ahead) else "NOT landed"
    elif branch is None:
        why = "landed"  # detached at or behind the trunk: nothing to lose
    elif branches.pr_merged(branch):
        why = "landed (PR merged)"
    elif not pushed:
        age = age_minutes(path)
        why = ("fresh" if age >= min_age
               else f"fresh, but touched {age:.0f}m ago (< --min-age {min_age})")
    else:
        why = "pushed, nothing ahead"
    desc = (f"{'dirty' if dirty else 'clean'}  {branch or '(detached)'}  "
            f"{len(ahead)} ahead, {why}; "
            + ("on origin" if pushed else "not on origin"))
    ok = not dirty and why in ("landed", "landed (PR merged)", "fresh")
    return ok, desc


def cmd_prune(args):
    root = root_of(args)
    here = os.path.realpath(git("rev-parse", "--show-toplevel"))
    fetch()
    landed = Landed(args.depth)
    todo, candidates = [], 0
    for worktree in linked_worktrees():
        real = os.path.realpath(worktree["path"])
        if not real.startswith(str(root) + os.sep):
            continue
        candidates += 1
        if worktree["prunable"]:
            print(f"keep    {worktree['path']}  missing on disk (git worktree prune clears it)")
            continue
        if worktree["locked"] or real == here:
            print(f"keep    {worktree['path']}  "
                  + ("locked" if worktree["locked"] else "the worktree this runs in"))
            continue
        ok, desc = verdict(worktree, landed, args.min_age)
        print(f"{'remove' if ok else 'keep  '}  {worktree['path']}  {desc}", flush=True)
        if ok:
            todo.append(worktree)
    if not candidates:
        print(f"no linked worktrees under {root}")
        return 0
    if not todo:
        print("\nnothing to remove")
        return 0
    if not args.yes:
        print(f"\n{len(todo)} removable; nothing done. Re-run with --yes.")
        return 0
    failed = 0
    for worktree in todo:
        result = git("worktree", "remove", worktree["path"], check=False)
        if result.returncode:
            failed += 1
            print(f"FAILED  git worktree remove {worktree['path']}: {result.stderr.strip()}")
            continue
        print(f"removed {worktree['path']}")
        if worktree["branch"]:
            result = git("branch", "-D", worktree["branch"], check=False)
            print(f"deleted branch {worktree['branch']}" if result.returncode == 0 else
                  f"FAILED  git branch -D {worktree['branch']}: {result.stderr.strip()}")
            failed += bool(result.returncode)
    return 1 if failed else 0


def main(argv=None):
    ap = argparse.ArgumentParser(prog="worktree.py",
                                 description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    subparser = sub.add_parser("new")
    subparser.add_argument("branch")
    subparser.add_argument("base", nargs="?", default=BASE)
    subparser.add_argument("--root")
    subparser.set_defaults(fn=cmd_new)
    subparser = sub.add_parser("prune")
    subparser.add_argument("--yes", action="store_true")
    subparser.add_argument("--root")
    subparser.add_argument("--min-age", type=float, default=60, metavar="MIN")
    subparser.add_argument("--depth", type=int, default=400)
    subparser.set_defaults(fn=cmd_prune)
    args = ap.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
