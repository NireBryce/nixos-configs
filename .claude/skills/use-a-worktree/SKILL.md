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

2026-08-30: two things working in the same checkout (`/Users/elly/nixos`)
at once — a `git checkout`, a commit, a branch delete from one side — were
each visible to the other immediately, mid-task, with no warning. Files
that had just been edited reverted to stale content; a branch swapped out
from under an in-progress task; a `git branch -f` failed because a branch
was checked out in what turned out to be the *other* session's directory.
Recognizing "something external changed this" instead of assuming a tool
had failed or an edit hadn't landed cost several turns each time. None of
it needed to happen — the two lines of work never actually touched the
same files.

A dedicated worktree per task removes the whole class of surprise: nobody
else's `checkout`/`commit`/`branch -d` can touch files you're looking at,
because they're a different working directory with a different `HEAD`,
backed by the same `.git` (so branches, objects, and `git worktree list`
are still shared and visible to both).

## How

**Create one**, based on whatever the task's target branch is (usually
`experimental` — see skill `ship`):

```sh
git -C /Users/elly/nixos fetch origin
git -C /Users/elly/nixos worktree add <scratchpad>/wt-<branch> -b <branch> origin/experimental
```

`<scratchpad>` is the scratchpad directory named in your own system
prompt — session-scoped, already the convention for temporary filesystem
state, and not something to invent a different location for. `<branch>`
should be the real branch name the task will end up shipping under, not a
throwaway label, so the worktree directory and the branch stay obviously
paired.

Then `cd` into it and work exactly as you would from the main checkout —
`just` recipes, `nix eval`, `nix flake check`, `git commit`, `gh pr
create` all work identically; it's a full, independent working directory,
not a partial or read-only view. **Verify you're actually in it**
(`git status -sb` or `pwd`) before running anything state-changing — the
harness's own bash tool can reset your shell's cwd between calls (seen
directly in this repo: `just` recipes that exec into a worktree print
"Shell cwd was reset to /Users/elly/nixos" afterward), so a multi-step
task needs the `cd` re-asserted or paths given absolutely, not assumed to
persist.

**Checking a specific commit/branch without touching any branch pointer**
(the `ship` skill's own step 0 case — verifying each commit in a PR is
green): use `--detach` instead of `-b`, since you're not going to commit
there:

```sh
git worktree add -q --detach <scratchpad>/wt-check <sha-or-ref>
```

**Clean up when done** — shipped or abandoned, don't leave it dangling:

```sh
git worktree remove --force <path>
```

`git branch -d <branch>` fails with "used by worktree at ..." while the
worktree still exists — remove the worktree first, not the other way
around. `git worktree list` (from any worktree, they all see the same
list) shows everything outstanding; worth a glance at the start of a
session for an orphaned one left by an earlier interrupted task. Don't
remove one you don't recognize without checking it first (`git -C <path>
status`, and note its `mtime`) — it may belong to another session running
right now.

## See also

- `AGENTS.md`, "Working in this repo" — the shared-checkout hazard this
  skill exists to prevent, in the compressed form that's always in context.
- Skill `ship` — step 0's "a throwaway worktree is the way" for checking
  every commit in a multi-commit PR is the same mechanism, narrower use.
