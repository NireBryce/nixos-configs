---
name: ship
description: Branch -> PR -> confirm merge-and-delete -> merge -> delete-branch flow for landing work on experimental in this repo.
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

Then, before opening a PR (CI, `.github/workflows/check.yml`: `just check` +
`just modules` + `just lint`, is a minutes-later backstop only):

```sh
just agent preflight-brief   # every step CI runs, one line each; `just preflight` for full output
nix eval --raw '.#nixosConfigurations.<host>.config.system.build.toplevel.drvPath'   # forced toplevel per config the change could touch
```

A cheap-attribute eval proves nothing (`AGENTS.md`, "Bugs here serialize").
If a drvPath moved, say *what* changed with `just diff HEAD` — a permuted
`systemPackages` order is not a value change.

Multi-commit change: check **each** commit is green (`lessons-learned.md`
§15) in a throwaway worktree:

```sh
git worktree add -q --detach /tmp/wt <sha> && cd /tmp/wt/flake
# ... check ...
git worktree remove --force /tmp/wt
```

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
  **Run and read that `git status --short` right before the reset** — the
  git-guard hook's `ask` is a no-op under `--permission-mode auto`
  (2026-09-06, issue #182) and its `systemMessage` warning doesn't stop an
  auto-mode agent. `git branch` preserves only the commit; other dirty state
  (someone else's uncommitted edit) is destroyed by `reset --hard` with no
  recovery. Anything beyond your commits: stop and ask.

Commit discipline:

- **Explicit pathspec, always** — `git commit -F <file> -- <paths...>`;
  `--amend` re-commits whatever is staged *right now*. Hit twice 2026-08-30,
  sweeping up unrelated staged files. Undo: `git reset --soft HEAD~1`, check
  `git status --short`, recommit with the right pathspec.
- **Backticks / `$(...)` in an inline message are executed by the shell**
  (2026-08-30: a backtick span became empty). Feed the message on stdin
  through a quoted heredoc, which the shell doesn't expand, rather than via
  a temp file: `git commit -F - -- <paths...> <<'EOF'` … `EOF`. Fix a
  mangled one the same way with `--amend -F -`.
- **Trailer**: `Co-Authored-By: <the agent you are>` — name only, no model,
  no email (Claude: `Co-Authored-By: Claude`).
- Branch name and first commit line get a `feat/`/`fix/`/`docs:` prefix
  (first line only; body stays what/why/verified narrative). Each commit
  green (§15); one coherent commit beats two artificial ones.

Then `just agent recurring export` (one line: this host's command shapes
to the private command log, skill `agent-scripts`; "not set up" is fine),
`git push -u origin <branch>`, and `gh pr create --base experimental
--body-file - <<'EOF'` (body on stdin, same reason as the commit message).
PR body: what changed, why, what was verified, what was left alone, under
`.github/PULL_REQUEST_TEMPLATE.md`'s headings. **LLM-disclosure line at both
top (before "What changed") and bottom** — a harness footer lands at the
bottom regardless. Use the model-agnostic `🤖 Generated by an LLM agent`
(`propose-issue`'s reasoning: an agent can't verify its model/harness); a
harness-injected footer is accurate by construction, no reason to name it up
top.

## 2. Preview, then ask

Read back what landed, never recall it:

```sh
gh pr checks <n> --watch --interval 20   # wait for CI; minutes, not optional
gh pr view --json url,title,additions,deletions,changedFiles,mergeable,mergeStateStatus,baseRefName
git log --oneline origin/experimental..HEAD
git diff --stat origin/experimental...HEAD
```

`mergeStateStatus` must be `CLEAN` and `baseRefName` `experimental`
**before** asking. **`mergeable` is not the CI answer** (only "no
conflicts"): #413 (2026-09-28) read `MERGEABLE` with red CI and
`mergeStateStatus` `BLOCKED`, and the ask went out calling it mergeable.
Red check: `gh run view <run> --log-failed`, fix, push, re-watch; if `just
preflight` passed locally, the step it missed belongs in `preflight` too.
Print the summary with the merge method and ask the one combined question:

- **Single commit** (common): default `--rebase`.
- **Multiple commits**: default `--merge` — individual commit messages carry
  real reasoning; squashing flattens it.

**No**: leave the PR open, say so, stop. Don't merge, close, delete, or clean up.

## 3. Merge, then delete — on yes only

```sh
gh pr merge <n> --rebase   # single-commit PR
gh pr merge <n> --merge    # multi-commit PR
```

Merge fails (unmergeable, required check pending, ruleset block): stop and
say so. Don't delete a branch whose PR didn't merge; raise it, don't retry
silently. On success delete immediately, no further ask:

```sh
git checkout experimental && git pull
git branch -d <branch>
git ls-remote --exit-code --heads origin <branch> >/dev/null \
  && git push origin --delete <branch>
```

`delete_branch_on_merge` is on, so the remote branch is normally already
gone and a bare `git push origin --delete` fails with `failed to push some
refs` (every ship since at least #416, 2026-09-28); the `ls-remote` guard
deletes only if it's still there.

**Never `gh pr merge --delete-branch`** — use the explicit steps above.

**Merged outside this flow** (web UI, another session): the branch stays.
`just branches` classifies local branches by patch-id, which catches rebased
merges (`git branch --merged` doesn't — rebasing gives new SHAs; 11 stale
branches accumulated by 2026-09-11 hiding 3 unmerged). `just branches prune`
deletes landed ones only and asks first — **agent sessions have no terminal
for the prompt, so pass `--yes`**; without it prune prints the verdict and
exits 2 deleting nothing. Glance at it at session start, like `git worktree
list`.

Report the merge commit and the branch's fate; never report a commit range
as if pushed to `experimental`.

**Closing keywords ("Fixes #N", "Closes #N", "Resolves #N") — verify.**
Broken 2026-09-06 (issue #177): three PRs with correct syntax merged into
`experimental`, GitHub didn't auto-close, `gh pr view <n> --json
closingIssuesReferences` empty, no error. After merging, for every issue the
body claims to fix:

```sh
gh issue view <N> --json state -q .state
gh issue close <N> --comment "..."   # if OPEN: what fixed it, which commit/PR
```

`just close-fixed <pr-number>` loops this: refuses unmerged PRs, unions
linked issues with the body's keyword mentions, closes only still-OPEN ones
with a comment saying it was a hand close (#177).

## Other flows

Promotion to `main`, branch rulesets, one-tree-two-PRs traps, named-branch
exception: [side-flows.md](side-flows.md).
