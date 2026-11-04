---
name: use-a-worktree
description: Sets up an isolated git worktree so work doesn't happen in the shared checkout.
when_to_use: Before any task that will branch, commit, merge or check out, at the first git command that moves a branch or changes what's checked out.
---

# Working in your own worktree

**Needs:** bash-guards

## Applies to

Use a worktree the first time in a session you are about to run a git command
that changes what is checked out or what a branch points at (`git checkout
-b`, `commit`, `merge`, `branch -f`/`-d`, `git worktree`) in this repo. Read-only
work (reading files, `nix eval`/`just check`/`just modules` on whatever is
checked out, grepping) does not need one.

Stay on the shared checkout when:

- The user names it explicitly or says to work there.
- The task is about its own state ("what's checked out", "clean up stray
  worktrees", continuing a branch already checked out there earlier in this
  conversation).
- You already made a worktree this conversation for the branch you are
  continuing (one per logical task or branch, not per tool call).

## Why

2026-08-30: two sessions shared one checkout and saw each other's
`checkout`, commit and `branch -d` mid-task: files reverted, branches swapped
out, and `git branch -f` failed because the branch was checked out in the other
session's directory. A worktree has its own directory and `HEAD` and shares the
same `.git` (branches, objects, `git worktree list`).

## How

**Subagents (Claude Code)**: pass `isolation: "worktree"` to the Agent tool.
Claude Code creates the worktree under `.claude/worktrees/` (gitignored) on its
own `worktree-agent-*` branch and removes it again if the agent changed nothing.
If the agent will ship, branch from the right base inside the agent. This needs
`.claude/` to be a real directory, not a symlink (it is, since 2026-10-02).

**Create**, based on the target branch (usually `experimental`, skill `ship`):

```sh
git -C <repo> fetch origin
git -C <repo> worktree add <scratchpad>/wt-<branch> -b <branch> origin/experimental
```

Or run `just agent worktree new <branch> [<base>] --root <scratchpad>`. It does
the same fetch and add, refuses an existing branch or path, and prints only the
path; `$AGENT_SCRATCH` stands in for `--root`. The directory is `wt-<branch
minus its feat/-style prefix>`.

`<scratchpad>` is the directory named in your system prompt (if none, `/tmp`).
`<branch>` is the real shipping branch, not a throwaway label. Then `just`,
`nix eval` and `gh pr create` work as usual. Verify you are in the worktree
(`git status -sb`, `pwd`, or `just agent where`, which also shows commits ahead
of `origin/experimental`) before anything state-changing. The bash tool can
reset cwd between calls, so re-`cd` or use absolute paths.

**Already edited in the shared checkout?** Move the edits instead of committing
there. Do this only when every dirty path is yours: run `git status --short`
first, and if anything else is dirty, stop and ask.

```sh
git diff > <scratchpad>/x.patch      # tracked edits; `git add -N` a new file first
just agent worktree new <branch> --root <scratchpad>
git -C <worktree> apply <scratchpad>/x.patch
```

Then clear the shared copies. The git guard denies `git checkout -- <paths>`
and `git restore` on a dirty tree, even after the user has approved the discard,
because it cannot see that approval. The route it allows, and names in its
denial, is stashing: `git stash push -m "<what>"`, then `git stash drop` (the
drop is permanent; the patch file and the worktree still hold the edits).

**Check a commit without touching a branch pointer** (ship step 0, each commit
of a multi-commit PR): use `--detach` instead of `-b`:

```sh
git worktree add -q --detach <scratchpad>/wt-check <sha-or-ref>
```

**Hooks caveat** (`just install-hooks`, `.githooks/`): a hook that runs `git`
from a cwd other than the worktree top (e.g. `cd flake && git add <path>`) must
use `git -C "$repo_root" add <repo-root-relative-path>`. `cd` plus an absolute
path is reinterpreted against the wrong root via inherited `GIT_DIR`.
`githooks(5)`'s suggested `unset $(git rev-parse --local-env-vars)` makes it
worse: it clears `GIT_INDEX_FILE`, which `git add` needs. §44 has the
mechanism; `.githooks/pre-commit` uses the `-C` form.

**Clean up** when shipped or abandoned:

```sh
git worktree remove --force <path>
```

`git branch -d` fails ("used by worktree at ...") until the worktree is removed,
so remove the worktree first, then the branch. `just agent ship-land` does this
from inside the worktree: it detaches the worktree at `origin/experimental`
(leaving the shared checkout's `experimental` alone) and deletes the branch;
you then remove the detached worktree. `-d` also refuses branches whose PR was
merged by rebase (new SHAs upstream); `just branches` settles that by patch-id,
and `just branches prune` deletes only provably landed ones.

`git worktree list` shows what is outstanding (Claude Code's SessionStart hook
prints it). Check it at session start for orphans, and do not remove an
unrecognized one without checking (`git -C <path> status`, mtime), because it
may belong to a live session. `just agent worktree prune --root <dir>` reports
each linked worktree under `<dir>` (clean or dirty, branch, landed on
`origin/experimental` by patch-id, on origin or not). With `--yes` it removes
only clean worktrees that landed, or that were never pushed with nothing ahead
and untouched for an hour (`--min-age`). It never removes dirty ones, the main
checkout, or the worktree it runs in.

## See also

`AGENTS.md` "Working in this repo"; skill `ship` step 0 (throwaway worktree,
narrower use); `wiki/agent-lessons-learned.md` §44 (the `GIT_DIR` hook bug in full).
