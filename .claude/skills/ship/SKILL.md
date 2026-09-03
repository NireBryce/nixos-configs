---
name: ship
description: Branch -> PR -> confirm -> merge -> confirm -> delete-branch flow for landing work on experimental in this repo.
---

# Landing work on experimental in nixos-configs

## Applies to

Fires only when the ask is to get changes onto `experimental`: a bare "push",
"ship it", "land this", "merge this". Established 2026-08-21 after a session
read a bare "push" as license for a direct push to `main`; the flow targets
`experimental` since 2026-08-25.

Does **not** fire for other git work — do those normally:

| ask | what to do |
|---|---|
| "push this branch" | `git push` it. No PR, no gates. |
| "open a PR" (no merge ask) | Open it and stop. Steps 3-4 are not yours to run. |
| "commit this" | Commit. Pushing was not asked for. |
| "promote to main" | Promotion flow — see "Promoting to `main`" below. Not a direct push; `main` carries its own ruleset. |
| any other branch named outright | Push directly there — see the last section. |
| fork, non-`origin` remote | Ordinary push. |

If unsure whether an ask means `experimental`, ask. Assuming *no* is the
mistake this file exists to prevent.

**The default branch is `experimental`** (2026-09-03, trunk + promotion
model — see the ruleset section at the bottom). `gh pr create` defaults to
the right trunk now; stating `--base experimental` explicitly is kept as a
harmless belt. `main` is the promoted known-good and moves only via a PR
from `experimental`.

There are **two** confirmations (merge, then branch deletion) — separate
questions, never collapsed, never delegated to `--delete-branch`.

## 0. Fetch, then is it green?

`git fetch origin` before anything else — other sessions land PRs
concurrently, and a branch cut from stale `experimental` makes the step-2
comparisons meaningless.

Then check before opening a PR. CI (`.github/workflows/check.yml`:
`just check` + `just modules` + `just lint`) is a minutes-later backstop,
not a substitute:

```sh
just preflight    # check + modules + lint in one shot; from repo root, not flake/
```

plus a forced toplevel per config the change could touch:

```sh
nix eval --raw '.#nixosConfigurations.<host>.config.system.build.toplevel.drvPath'
```

Evaluating a cheap attribute proves nothing (`AGENTS.md`, "Bugs here
serialize"). If a drvPath moved, say *what* changed with `just diff HEAD` —
a permuted `systemPackages` order is not a value change.

Multi-commit change: check **each** commit is green (`lessons-learned.md`
§15), via a throwaway worktree:

```sh
git worktree add -q --detach /tmp/wt <sha> && cd /tmp/wt/flake
# ... check ...
git worktree remove --force /tmp/wt
```

## 1. Branch, push, open the PR

Never commit onto `experimental`. `git status -sb` (already fetched) first:

- **Dirty tree on `experimental`**: `git checkout -b <branch>` and commit
  there. Nothing to rescue.
- **Unpushed commits sitting on local `experimental`** (`[ahead N]`):
  ```sh
  git branch <branch>              # keep the commits
  git reset --hard origin/experimental
  git checkout <branch>
  ```

Commit discipline:

- **Explicit pathspec, always** — `git commit -F <file> -- <paths...>`, and
  `--amend` re-commits whatever is staged *right now*, not "previous commit
  plus message". Hit twice 2026-08-30, both times sweeping up unrelated
  staged files. To undo a bad commit: `git reset --soft HEAD~1`, check `git
  status --short`, recommit with the right pathspec.
- **Backticks / `$(...)` in a message written inline get executed by the
  shell before git sees them** (hit 2026-08-30: a backtick span silently
  became empty output). Write the message to a file and `git commit -F
  <file>`; fix a mangled one with `--amend -F <file>`.
- **Provenance trailer**: `Co-Authored-By: <the agent you are>` — agent
  name only, no model, no email. Claude's canonical form is `Co-Authored-By:
  Claude`.
- Branch name and first commit-message line get a `feat/`/`fix/`/`docs:`
  prefix (Conventional-Commits style on the first line only; the body stays
  this repo's narrative what/why/verified style). Order commits so each is
  green (§15) — one coherent commit beats two artificial ones.

Then `git push -u origin <branch>` and `gh pr create --base experimental`.
Write the PR body like the commit messages: what changed, why, what was
verified, what was left alone — matching `.github/PULL_REQUEST_TEMPLATE.md`'s
headings.

## 2. Preview, then ask — first confirmation

Read back what actually landed, never recall it:

```sh
gh pr view --json url,title,additions,deletions,changedFiles,mergeable,baseRefName
git log --oneline origin/experimental..HEAD
git diff --stat origin/experimental...HEAD
```

Check `mergeable` and that `baseRefName` is `experimental` **before** asking
— a wrong base or unmergeable PR wastes the round-trip. Print the summary,
include the merge method, ask whether to merge:

- **Single commit** (the common case): default `--rebase` — `--merge` is a
  bubble for nothing on a one-commit PR.
- **Multiple commits**: default `--merge` — this repo puts real reasoning in
  individual commit messages; squashing flattens it.

On **no**: leave the PR open, say so, stop. Do not close it, delete the
branch, or clean up.

## 3. Merge — on yes only

```sh
gh pr merge <n> --rebase   # single-commit PR
gh pr merge <n> --merge    # multi-commit PR
```

**Never `--delete-branch`** — it silently removes the second confirmation.

## 4. Ask again, then delete — second confirmation

A separate round-trip from the merge ask. On yes:

```sh
git checkout experimental && git pull
git branch -d <branch>
git push origin --delete <branch>
```

On no, leave it and say it is still there. Report the merge commit and the
branch's fate; never report a commit range as if pushed to `experimental`.

## When one working tree becomes two PRs

Both bit 2026-08-21 (#43/#44):

- **`cp` is aliased `cp -i` here** (`~/.zshrc`, HM-generated). Non-interactive,
  it answers its own prompt and **exits 0 without copying**. Use `cat src >
  dst` or `command cp` when reconstructing file states. (Written `alias --
  cp='cp -i'`, so `grep 'alias cp='` misses it.) Caught by an empty staged
  diff, not by anything the copy said — §1, a tool reporting success while
  wrong.
- **A stacked PR is not retargeted when its base merges** (only when the base
  *branch is deleted* — step 4, which needs its own confirmation). Retarget
  explicitly before merging the child: `gh pr edit <child> --base
  experimental`. Both gates still apply per PR, but a harness can batch the
  two merge questions into one call — still one question per decision. Name
  which PR is stacked on which, so an incoherent answer is visibly
  incoherent.

## The ruleset picture (trunk + promotion, 2026-09-03)

Two rulesets, both enforced by GitHub:

- **`experimental` (the default branch)** — the ruleset added for `main`
  2026-08-21 targets `~DEFAULT_BRANCH`, so it followed the default-branch
  flip automatically: no deletion, no force-push, PR required (zero
  approvals — solo repo), CI check required. The two conversational
  confirmations remain the guard on *top* of this — they gate the merge
  decision, the ruleset gates everything else.
- **`main` (promoted known-good)** — protected by name: same rules. It
  moves only via a PR from `experimental` (the promotion flow below), and
  only for configs verified on hardware.

## Promoting to `main`

On a "promote to main"-shaped ask (not part of the ordinary flow above):

```sh
gh pr create --base main --head experimental \
  --title "promote: <one line on what's verified>" \
  --body "what landed since the last promotion, and where it was booted/switched"
gh pr merge <n> --rebase    # experimental is strictly ahead; keeps history linear
```

The promotion PR is the record of *why* `main` moved — write what was
verified on hardware, not just the commit range. Only promote after the
config has actually booted/switched on the hosts it touches; an unverified
trunk is what `experimental` is for.

## Only when Elly names a branch

Elly naming a branch outright for that push — any branch except `main`,
which is promotion-only (see above). A bare "push" is not that; it means
the guarded flow above, onto `experimental`.
