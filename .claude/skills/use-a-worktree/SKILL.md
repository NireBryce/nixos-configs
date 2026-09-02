---
name: use-a-worktree
description: How to work in an isolated git worktree instead of the shared checkout in this repo.
---

# Working in your own worktree

## Applies to

The first time in a session you're about to run a git command that changes
what's checked out or what a branch points at — `git checkout -b`, `git
commit`, `git merge`, `git branch -f`/`-d`, `git worktree` itself — in this
repo. Not for read-only work: answering a question by reading files,
running `nix eval`/`just check`/`just modules` against whatever's already
checked out, or grepping around. Nothing in this skill needs to happen
before *that*.

Skip it, and stay on the shared checkout, when:

- **The user names the shared checkout explicitly**, or says to work there
  directly.
- **The task is about the shared checkout's own state** — "what's checked
  out right now," "clean up stray worktrees," continuing a branch that's
  already checked out there from earlier in the same conversation.
- **You already made a worktree earlier in this same conversation** for
  the branch you're continuing — one per logical task/branch, not one per
  tool call.

## Why

2026-08-30: two sessions shared one checkout; each saw the other's
`checkout`/commit/`branch -d` immediately, mid-task — files reverting, a
branch swapped out from under in-progress work, a `git branch -f` failing
because the branch was checked out in the *other* session's directory.
Telling "something external changed this" from "my edit didn't land" cost
several turns each time, and none of it needed to happen.

A dedicated worktree removes the whole class: nobody else's
checkout/commit can touch the files you're looking at, because it's a
different working directory with a different `HEAD`, backed by the same
`.git` (branches, objects, `git worktree list` still shared and visible to
both).

## How

**Create one**, based on the task's target branch (usually `experimental` —
skill `ship`):

```sh
git -C <repo> fetch origin
git -C <repo> worktree add <scratchpad>/wt-<branch> -b <branch> origin/experimental
```

`<scratchpad>` is the scratchpad directory named in your own system prompt;
`<branch>` is the real branch the task ships under, not a throwaway label.
Then work in it exactly as from the main checkout — `just` recipes, `nix
eval`, `gh pr create` all work identically. **Verify you're actually in it**
(`git status -sb` or `pwd`) before anything state-changing — the bash tool
can reset your shell's cwd between calls, so re-assert the `cd` or use
absolute paths.

**Checking a commit without touching a branch pointer** (ship step 0:
verifying each commit in a multi-commit PR): use `--detach` instead of
`-b`:

```sh
git worktree add -q --detach <scratchpad>/wt-check <sha-or-ref>
```

**Hooks caveat** (`just install-hooks`, `.githooks/`): a hook running `git`
from a different cwd than the worktree top (e.g. `cd flake && git add
<path>`) must use `git -C "$repo_root" add <repo-root-relative-path>` — a
`cd` plus absolute path gets silently reinterpreted against the wrong root
via the inherited `GIT_DIR`. The fix `githooks(5)` suggests
(`unset $(git rev-parse --local-env-vars)`) makes it worse here: it also
clears `GIT_INDEX_FILE`, which that `git add` needs. §44 has the full
mechanism. `.githooks/pre-commit` already uses the `-C` form — relevant if
you ever write a new hook.

**Clean up when done** — shipped or abandoned:

```sh
git worktree remove --force <path>
```

`git branch -d` fails with "used by worktree at ..." until the worktree is
removed — worktree first, then branch. `git worktree list` (visible from
any worktree) shows what's outstanding; glance at session start for
orphans, and don't remove one you don't recognize without checking (`git
-C <path> status`, its mtime) — it may belong to a session running now.

## See also

- `AGENTS.md`, "Working in this repo" — the shared-checkout hazard this
  skill exists to prevent, in the compressed form that's always in context.
- Skill `ship` — step 0's "a throwaway worktree is the way" for checking
  every commit in a multi-commit PR is the same mechanism, narrower use.
- `wiki/lessons-learned.md` §44 — the `.githooks/pre-commit` +
  `GIT_DIR` bug this page's "hooks are installed" note summarizes, in
  full: how it was reproduced, the `githooks(5)` citation, and the fix.
