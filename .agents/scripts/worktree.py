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


def git(*args, cwd=None, check=True):
    r = subprocess.run(["git", *([] if cwd is None else ["-C", str(cwd)]), *args],
                       capture_output=True, text=True)
    if check and r.returncode != 0:
        sys.exit(f"git {' '.join(args)} failed:\n{r.stderr.strip()}")
    return r.stdout.strip() if check else r


def root_of(a):
    r = a.root or os.environ.get("AGENT_SCRATCH") or "/tmp"
    return Path(os.path.realpath(r))


def dir_name(branch):
    rest = branch.split("/", 1)[1] if "/" in branch else branch
    return "wt-" + rest.replace("/", "-")


def fetch():
    r = subprocess.run(["git", "fetch", "-q", "--prune", "origin"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print(f"warning: git fetch origin failed: {r.stderr.strip()}",
              file=sys.stderr)


def cmd_new(a):
    root = root_of(a)
    path = root / dir_name(a.branch)
    if not re.fullmatch(r"[A-Za-z0-9._/-]+", a.branch) or git(
            "check-ref-format", "--branch", a.branch, check=False).returncode:
        sys.exit(f"refusing: {a.branch!r} is not a usable branch name")
    fetch()
    for ref in (f"refs/heads/{a.branch}", f"refs/remotes/origin/{a.branch}"):
        if git("rev-parse", "-q", "--verify", ref, check=False).returncode == 0:
            sys.exit(f"refusing: {ref} already exists")
    if path.exists() or path.is_symlink():
        sys.exit(f"refusing: {path} already exists")
    root.mkdir(parents=True, exist_ok=True)
    r = subprocess.run(["git", "worktree", "add", "-q", str(path), "-b",
                        a.branch, a.base], capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"git worktree add failed:\n{r.stderr.strip()}")
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
    times = [os.path.getmtime(p) for p in (Path(gitdir) / "HEAD",
                                           Path(gitdir) / "index") if p.exists()]
    return (time.time() - max(times)) / 60 if times else 0


class Landed:
    """Patch-ids of origin/experimental, computed once and only if asked."""

    def __init__(self, depth):
        self.depth, self.ids = depth, None

    def check(self, commits):
        if self.ids is None:
            branches.TRUNK = BASE
            self.ids = branches.trunk_patch_ids(self.depth)
        pids = [branches.patch_id(c) for c in commits]
        readable = [p for p in pids if p]
        return bool(readable) and all(p in self.ids for p in readable)


def verdict(w, landed, min_age):
    """-> (removable, description)."""
    path, b = w["path"], w["branch"]
    dirty = bool(git("status", "--porcelain", cwd=path))
    ahead = git("rev-list", f"{BASE}..HEAD", cwd=path).split()
    pushed = b is not None and git("rev-parse", "-q", "--verify",
                                   f"refs/remotes/origin/{b}",
                                   check=False).returncode == 0
    if ahead:
        why = "landed" if landed.check(ahead) else "NOT landed"
    elif b is None:
        why = "landed"  # detached at or behind the trunk: nothing to lose
    elif branches.pr_merged(b):
        why = "landed (PR merged)"
    elif not pushed:
        age = age_minutes(path)
        why = ("fresh" if age >= min_age
               else f"fresh, but touched {age:.0f}m ago (< --min-age {min_age})")
    else:
        why = "pushed, nothing ahead"
    desc = (f"{'dirty' if dirty else 'clean'}  {b or '(detached)'}  "
            f"{len(ahead)} ahead, {why}; "
            + ("on origin" if pushed else "not on origin"))
    ok = not dirty and why in ("landed", "landed (PR merged)", "fresh")
    return ok, desc


def cmd_prune(a):
    root = root_of(a)
    here = os.path.realpath(git("rev-parse", "--show-toplevel"))
    fetch()
    landed = Landed(a.depth)
    todo, n = [], 0
    for w in linked_worktrees():
        real = os.path.realpath(w["path"])
        if not real.startswith(str(root) + os.sep):
            continue
        n += 1
        if w["prunable"]:
            print(f"keep    {w['path']}  missing on disk (git worktree prune clears it)")
            continue
        if w["locked"] or real == here:
            print(f"keep    {w['path']}  "
                  + ("locked" if w["locked"] else "the worktree this runs in"))
            continue
        ok, desc = verdict(w, landed, a.min_age)
        print(f"{'remove' if ok else 'keep  '}  {w['path']}  {desc}", flush=True)
        if ok:
            todo.append(w)
    if not n:
        print(f"no linked worktrees under {root}")
        return 0
    if not todo:
        print("\nnothing to remove")
        return 0
    if not a.yes:
        print(f"\n{len(todo)} removable; nothing done. Re-run with --yes.")
        return 0
    failed = 0
    for w in todo:
        r = git("worktree", "remove", w["path"], check=False)
        if r.returncode:
            failed += 1
            print(f"FAILED  git worktree remove {w['path']}: {r.stderr.strip()}")
            continue
        print(f"removed {w['path']}")
        if w["branch"]:
            r = git("branch", "-D", w["branch"], check=False)
            print(f"deleted branch {w['branch']}" if r.returncode == 0 else
                  f"FAILED  git branch -D {w['branch']}: {r.stderr.strip()}")
            failed += bool(r.returncode)
    return 1 if failed else 0


def main(argv=None):
    ap = argparse.ArgumentParser(prog="worktree.py",
                                 description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("new")
    p.add_argument("branch")
    p.add_argument("base", nargs="?", default=BASE)
    p.add_argument("--root")
    p.set_defaults(fn=cmd_new)
    p = sub.add_parser("prune")
    p.add_argument("--yes", action="store_true")
    p.add_argument("--root")
    p.add_argument("--min-age", type=float, default=60, metavar="MIN")
    p.add_argument("--depth", type=int, default=400)
    p.set_defaults(fn=cmd_prune)
    a = ap.parse_args(argv)
    return a.fn(a)


if __name__ == "__main__":
    sys.exit(main())
