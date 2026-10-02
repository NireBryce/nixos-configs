---
name: ship
description: Branch -> PR -> confirm merge-and-delete -> merge -> delete-branch flow for landing work on experimental in this repo.
when_to_use: A bare "push", "ship it", "land this", or "merge this" -- any ask to get changes onto experimental, never a direct push to main.
---

# Landing work on experimental in nixos-configs

## Applies to

Fires only when the ask is to get changes onto `experimental`: a bare "push",
"ship it", "land this", "merge this". Established 2026-08-21 after a session
read a bare "push" as license for a direct push to `main`; targets
`experimental` since 2026-08-25.

Does **not** fire for other git work:

| ask | what to do |
|---|---|
| "push this branch" | `git push` it. No PR, no gates. |
| "open a PR" (no merge ask) | Open it and stop. Steps 2-3 are not yours to run. |
| "commit this" | Commit. Pushing was not asked for. |
| "promote to main" | Promotion flow — [side-flows.md](side-flows.md), not a direct push; `main` has its own ruleset. |
| any other branch named outright | Push directly there — [side-flows.md](side-flows.md). |
| fork, non-`origin` remote | Ordinary push. |

If unsure whether an ask means `experimental`, ask. Assuming *no* is the
mistake this file exists to prevent.

`experimental` is the default branch (2026-09-03, trunk + promotion; ruleset
picture in [side-flows.md](side-flows.md)); `gh pr create` defaults to it,
`--base experimental` stays as a harmless belt. `main` moves only via a PR
from `experimental`.

**One** confirmation, asked up front, covers both actions: "merge, and delete
the branch afterward?" On yes both happen in the same turn. Not
`--delete-branch` (removes only the remote branch; the flow also wants the
local branch gone and `experimental` checked out and pulled). Collapsed from
two asks 2026-09-05.

## 0. Fetch, then is it green?

`git fetch origin` first — other sessions land PRs concurrently; a branch cut
from stale `experimental` makes step-2 comparisons meaningless.

Then, before opening a PR (CI, `.github/workflows/check.yml`, runs the same
`just preflight` minutes later — a backstop only):

```sh
just agent preflight-brief   # all of preflight, one line per step; `just preflight` for full output
```

Its `just check` forces every host's toplevel and home, darwin included
(`flake/modules/checks.nix`, since 2026-09-29), so there is no host to pick.
If a drvPath moved, say *what* changed with `just diff HEAD` — a permuted
`systemPackages` order is not a value change.

Multi-commit change: check **each** commit is green (`lessons-learned.md`
§15):

```sh
just agent preflight-each [<range>]   # default origin/experimental..HEAD
```

`preflight-brief` on every commit, oldest first, in one throwaway detached
worktree removed on any exit (Ctrl-C too); one `ok`/`FAIL` line per commit
as it finishes, so it suits a background runner. Non-zero if any failed.

## 1. Branch, push, open the PR

Never commit onto `experimental`. `git status -sb` first:

- **Dirty tree on `experimental`**: `git checkout -b <branch>`, commit there.
- **Unpushed commits on local `experimental`** (`[ahead N]`):
  ```sh
  git branch <branch>              # keep the commits
  git status --short               # anything NOT part of those commits?
  git reset --hard origin/experimental
  git checkout <branch>
  ```
  **Read that `git status --short` before the reset.** `git branch`
  preserves only the commit; other dirty state (someone else's uncommitted
  edit) is destroyed by `reset --hard` with no recovery. Anything beyond
  your commits: stop and ask. The git-guard hook now denies `reset --hard`
  on a dirty tree (since 2026-09-29; its old `ask` was a no-op under
  `--permission-mode auto`, issue #182), but only in Claude Code, and it
  falls back to `ask` — still a no-op under auto mode — when it can't tell
  which repo the reset acts on: anything beyond plain `cd <path>` and
  `git [-C <path>] <subcommand> <args>` joined by `&&`/`;`. So the
  `git status --short` read stays yours.

Commit with `just agent commit` (`.agents/scripts/ship.py`, whose header
has the incidents behind each rule):

```sh
just agent commit [--agent <you>] -- <paths...> <<'EOF'
feat: ...
EOF
```

It requires a pathspec (a bare commit or `--amend` takes whatever is staged
now), reads the message on stdin (a quoted heredoc, so backticks and
`$(...)` aren't executed), refuses `experimental` and `main`, and appends
`Co-Authored-By: <agent>` (default `Claude`; name only, no model, no email)
unless the message already has one. Committed the wrong paths: `git reset
--soft HEAD~1`, check `git status --short`, recommit. `--amend` isn't
wrapped: `git commit --amend -F - -- <paths...> <<'EOF'`.

- Branch name and first commit line get a `feat/`/`fix/`/`docs:` prefix
  (first line only; body stays what/why/verified narrative). Each commit
  green (§15); one coherent commit beats two artificial ones. The message
  describes only what this commit contains, never a note or fix still to
  come.

Then `just agent recurring export` (one line: this host's command shapes
to the private command log, skill `agent-scripts`; "not set up" or a
failure is reported, not a reason to stop), write the body to a file, and

```sh
just agent pr <body-file> [--title T]   # --edit <n> replaces an open PR's body
```

It pushes with `-u` when the branch has no `origin/<branch>` upstream (a
branch cut from `origin/experimental` tracks the trunk, so a bare push
fails), then `gh pr create --base experimental --body-file`. Title
defaults to the only commit's subject; several commits need `--title`.
It refuses on `experimental`/`main` and refuses a body missing the
disclosure line at top or bottom (below). The body is a file because
backticks in an inline `--body` are executed, as in a commit message.
PR body: what changed, why, what was verified, what was left alone, under
`.github/PULL_REQUEST_TEMPLATE.md`'s headings. Security-relevant change:
the PR body and commit messages state what is now enforced, never what got
past the old version or what it could reach -- that goes to
`elly/infra-notes` (AGENTS.md, Working in this repo). **LLM-disclosure line at both
top (before "What changed") and bottom** — a harness footer lands at the
bottom regardless. Use the model-agnostic `🤖 Generated by an LLM agent`
(`propose-issue`'s reasoning: an agent can't verify its model/harness); a
harness-injected footer is accurate by construction, no reason to name it up
top.

## 2. Preview, then ask

Read back what landed, never recall it:

```sh
just agent ship-ready <n>
```

It waits for CI (`gh pr checks --watch`, minutes, not optional), then gates:
PR open, `mergeStateStatus` `CLEAN` (not `mergeable`, which only means no
conflicts: #413), base `experimental`. It prints title, URL, stats, the
commit list, and the merge method: one commit `--rebase`, more `--merge`
(their messages carry real reasoning; squashing flattens it). **NOT READY**
means don't ask: fix what it names. Red check: `gh run view <run>
--log-failed`, fix, push, re-run; if `just preflight` passed locally, the
step it missed belongs in `preflight` too.

**READY**: show that summary and ask the one combined question.

**No**: leave the PR open, say so, stop. Don't merge, close, delete, or clean up.

## 3. Merge, then delete — on yes only

```sh
just agent ship-land <n>
```

It re-runs the gate and refuses if it fails, merges with the computed
method (never `--delete-branch`, pinned to the head commit the gate read),
confirms `MERGED`, then: `experimental` checked out and pulled (from a
linked worktree whose shared checkout holds `experimental`, it leaves that
checkout alone and detaches this worktree instead), local branch deleted,
remote branch deleted if still there, `just close-fixed <n>` (#177: closing
keywords silently not closing). Any failure stops it and prints what's left;
a failed merge deletes nothing. Raise that, don't retry silently.

**Merged outside this flow** (web UI, another session): the branch stays.
`just branches` classifies local branches by patch-id, which catches rebased
merges (`git branch --merged` doesn't — rebasing gives new SHAs; 11 stale
branches accumulated by 2026-09-11 hiding 3 unmerged). `just branches prune`
deletes landed ones only and asks first — **agent sessions have no terminal
for the prompt, so pass `--yes`**; without it prune prints the verdict and
exits 2 deleting nothing. Glance at it at session start, like `git worktree
list`.

Report the merge commit and the branch's fate (including anything
`ship-land` left for you); never report a commit range as if pushed to
`experimental`. After a land that ran outside `ship-land`, still run `just
close-fixed <n>`: it re-checks every issue the PR claims to fix and closes
the ones still OPEN, with a comment saying it was a hand close.

## Other flows

Promotion to `main`, branch rulesets, one-tree-two-PRs traps, named-branch
exception: [side-flows.md](side-flows.md).

A merge conflict in `.claude/settings.local.json` is the user's local
allowlist, not shipped config: take the simplest resolution and move on
(§42).
