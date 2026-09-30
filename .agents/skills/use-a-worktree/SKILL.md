---
name: use-a-worktree
description: How to work in an isolated git worktree instead of the shared checkout in this repo.
---

# Working in your own worktree

## Applies to

The first time in a session you're about to run a git command that changes
what's checked out or what a branch points at (`git checkout -b`, `commit`,
`merge`, `branch -f`/`-d`, `git worktree`) in this repo. Not read-only work
(reading files, `nix eval`/`just check`/`just modules` on whatever's checked
out, grepping).

Stay on the shared checkout when:

- The user names it explicitly or says to work there.
- The task is about its own state ("what's checked out", "clean up stray
  worktrees", continuing a branch already checked out there earlier in this
  conversation).
- You already made a worktree this conversation for the branch you're
  continuing (one per logical task/branch, not per tool call).

## Why

2026-08-30: two sessions shared one checkout and saw each other's
`checkout`/commit/`branch -d` mid-task: files reverting, branches swapped
out, `git branch -f` failing because the branch was checked out in the
*other* session's directory. A worktree has its own directory and `HEAD`,
same `.git` (branches, objects, `git worktree list` shared).

## How

**Create**, based on the target branch (usually `experimental`, skill `ship`):

```sh
git -C <repo> fetch origin
git -C <repo> worktree add <scratchpad>/wt-<branch> -b <branch> origin/experimental
```

`<scratchpad>` is the directory named in your system prompt (none: `/tmp`);
`<branch>` is the real shipping branch, not a throwaway label. Then `just`,
`nix eval`, `gh pr create` all work as usual. **Verify you're in it** (`git
status -sb` or `pwd`) before anything state-changing; the bash tool can
reset cwd between calls, so re-`cd` or use absolute paths.

**Check a commit without touching a branch pointer** (ship step 0, each
commit of a multi-commit PR): `--detach` instead of `-b`:

```sh
git worktree add -q --detach <scratchpad>/wt-check <sha-or-ref>
```

**Hooks caveat** (`just install-hooks`, `.githooks/`): a hook running `git`
from a cwd other than the worktree top (e.g. `cd flake && git add <path>`)
must use `git -C "$repo_root" add <repo-root-relative-path>`; `cd` plus an
absolute path is reinterpreted against the wrong root via inherited
`GIT_DIR`. `githooks(5)`'s suggested `unset $(git rev-parse
--local-env-vars)` makes it worse: it clears `GIT_INDEX_FILE`, which `git
add` needs. §44 has the mechanism; `.githooks/pre-commit` uses the `-C` form.

**Clean up** when shipped or abandoned:

```sh
git worktree remove --force <path>
```

`git branch -d` fails ("used by worktree at ...") until the worktree is
removed: worktree first, then branch. `-d` also refuses branches whose PR
was merged by REBASE (new SHAs upstream); `just branches` settles that by
patch-id, `just branches prune` deletes only provably landed ones. `git
worktree list` shows what's outstanding (Claude Code's SessionStart hook
prints it); glance at it at session start for orphans, and don't remove an
unrecognized one without checking (`git -C <path> status`, mtime) — it may
belong to a live session.

## See also

`AGENTS.md` "Working in this repo"; skill `ship` step 0 (throwaway worktree,
narrower use); `wiki/lessons-learned.md` §44 (the `GIT_DIR` hook bug in full).
