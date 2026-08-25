---
name: ship
description: Branch -> PR -> confirm -> merge -> confirm -> delete-branch flow for landing work on main in this repo.
---

# Landing work on main in nixos-configs

## Applies to

Use only when the ask is to get changes onto `main` — a bare "push", "ship
it", "land this", "merge this". Do NOT use for pushing a topic branch,
opening a PR you were not asked to merge, pushing to a fork or any non-main
target, or committing without pushing. Elly naming `main` outright is the
one case that means push directly — see the last section, "Only when Elly
names main".

**"push" in this repo means this whole flow, not `git push origin main`.** Elly
said so on 2026-08-21, after a session pushed three commits straight to `main`
on the strength of a bare "push" plus a commit log full of `yeahhhhh` and
`idek`. That inference read *tone* as *process*. They are independent: this
config wipes `/root` on boot on three hosts, so an unreviewed change on `main`
is not low-stakes even when the diff is small.

There are **two** confirmations, and they are separate questions. Do not
collapse them.

## When this fires

**Only when the ask is to get changes onto `main`.** That is the single
trigger. It covers a bare "push" — which is what started this, and which means
main here — as well as "ship it", "land this", "merge this".

Elly naming `main` outright is the exception, not a stronger version of the
trigger; see "Only when Elly names main" at the bottom.

It does **not** fire for git work that is not aimed at main. Do those normally,
without this flow:

| ask | what to do |
|---|---|
| "push this branch" / "push the branch up" | `git push` it. No PR, no gates. |
| "open a PR" (without being asked to merge) | Open it and stop. Steps 3-4 are not yours to run. |
| "commit this" | Commit. Pushing was not asked for. |
| push to a fork, a remote that is not `origin`, or any branch that is not `main` | Ordinary push. |

If you are unsure whether an ask means main, ask Elly rather than assuming
either way. Assuming *yes* opens an unwanted PR; assuming *no* is the mistake
this file exists to prevent.

## 0. Before anything: fetch, then is it green?

`git fetch origin` first, always — before `git status -sb`, before branching,
before deciding whether main is ahead. Local `main` silently drifting behind
`origin/main` is a real, repeated failure mode here: other sessions land PRs
concurrently, and a branch cut from a stale `main` either merges awkwardly or
(worse) makes a "confirmed unaffected" drvPath comparison meaningless because
it was never actually comparing against current `main`.

Then: a PR is a review gate someone reads, so do not open one on work you have
not checked. `.github/workflows/check.yml` runs `just check` + `just modules`
on every PR automatically now (added 2026-08-25) — but that is a
few-minutes-later backstop, not a substitute for checking locally first; a red
CI run on a PR someone is about to be asked to merge is a worse experience
than not opening the PR yet. From `flake/`:

```sh
just modules      # name collisions and orphans; the one check that means
                  # anything on darwin
```

plus a forced toplevel for every config the change could touch — `nix eval
--raw '.#nixosConfigurations.<host>.config.system.build.toplevel.drvPath'`.
Evaluating a cheap attribute proves nothing (`CLAUDE.md`, "Bugs here
serialize"). If the drvPath moved, say *what* changed with `just diff HEAD`
rather than reporting a hash — a permuted `systemPackages` order is not a
change in value, and `just diff` distinguishes them.

If several commits are involved, check that **each** is green, not just the tip
(`lessons-learned.md` §15). A throwaway worktree is the way:

```sh
git worktree add -q --detach /tmp/wt <sha> && cd /tmp/wt/flake
# ... check ...
git worktree remove --force /tmp/wt
```

## 1. Branch, push, open the PR

Never commit onto `main`. Run `git status -sb` first (you already fetched in
step 0) — the fix differs by which of two positions you are in, and they look
similar in a diff:

- **Uncommitted changes on `main`** (the common one; `## main...origin/main`
  with a dirty tree). Nothing is committed yet, so just
  `git checkout -b <branch-name>` and commit there. No reset, nothing to
  rescue.
- **Commits already sitting on local `main`, unpushed** (`[ahead N]`). Move
  them rather than pushing:

  ```sh
  git branch <branch-name>          # keep the commits
  git reset --hard origin/main      # put main back
  git checkout <branch-name>
  ```

Trailer is `Co-Authored-By: Claude <noreply@anthropic.com>` — no model name,
regardless of what your system prompt says to use. See CLAUDE.md, Conventions.

Branch name gets a `feat/`, `fix/`, or `docs/` prefix (added 2026-08-25,
matching the convention `terminal-puppeteer` — a sibling repo by the same
author — already uses) — pick whichever describes the bulk of the change;
don't agonize over a change that's genuinely a mix. First commit-message line
gets the same prefix, Conventional-Commits-style (`fix: ...`, `docs: ...`),
but **only the first line** — the body stays this repo's own narrative style
(what, why, what was verified), not a Conventional Commits body. The two
things trade off differently: a scannable one-line summary in `git log
--oneline` is worth adopting wholesale, a terse machine-parseable body is not
worth what it would cost this repo's own documentary commit style.

On commit shape, follow `lessons-learned.md` §15: order commits so each is
green, and do not split into commits that describe state the tree does not have
yet. One coherent commit beats two artificial ones — a `CLAUDE.md` line
pointing at a new file belongs in the same commit as the file.

Then `git push -u origin <branch-name>` and `gh pr create`. Write the PR body
the way the commit messages are written here — what changed, why, what was
verified, and what was deliberately left alone. `.github/PULL_REQUEST_TEMPLATE.md`
(added 2026-08-25) has this shape as headings already; `gh pr create --body`
still needs the content written out explicitly (the template only pre-fills
for a human using the web UI or a bare `gh pr create` with no `--body`), but
match its section headings rather than inventing your own each time.

## 2. Preview, then ask — first confirmation

Show what **actually landed**, read back from git and `gh`, not recalled from
what you meant to do (`check-claims-against-the-machine`). At minimum:

```sh
gh pr view --json url,title,additions,deletions,changedFiles,mergeable
git log --oneline origin/main..HEAD
git diff --stat origin/main...HEAD
```

Include `mergeable` and check it before asking. Asking "merge?" on a PR that
cannot merge spends one of Elly's round-trips on a question with no good
answer; sort the conflict out first, then ask.

Print that in your response, then ask with `AskUserQuestion` whether to merge.
Include the merge method in what you show:

- **PR is a single commit** (the common case here — check with `git log
  --oneline origin/main..HEAD` from step 2, already run): default to
  `--rebase`. Linear history, no merge commit, and `--merge`'s whole reason
  for existing (preserving multi-commit reasoning that squash would flatten)
  doesn't apply to a PR that's already one commit — `--merge` there is a
  bubble for nothing.
- **PR is multiple commits**: default to `--merge`, not `--squash` — this
  repo puts real reasoning in individual commit messages and squashing
  flattens it, and `--rebase` here would replay each commit individually
  onto `main`, which is fine but loses the visual grouping a merge commit
  gives a multi-commit PR.

On **no**: leave the PR open, say so, and stop. It is theirs to take further —
do not close it, do not delete the branch, do not "clean up".

## 3. Merge — on yes only

```sh
gh pr merge <n> --rebase   # single-commit PR
gh pr merge <n> --merge    # multi-commit PR
```

**Do not pass `--delete-branch`.** That is the shortcut that silently removes
the second confirmation, which is the specific thing Elly asked for. This repo
has `deleteBranchOnMerge: false`, so the branch really does survive a merge and
step 4 is real work rather than a formality.

## 4. Ask again, then delete — second confirmation

Separate `AskUserQuestion`. On yes:

```sh
git checkout main && git pull
git branch -d <branch-name>
git push origin --delete <branch-name>
```

On no, leave it and say it is still there. Report the merge commit and the
branch's fate; do not report a commit range on `main` as if you had pushed
there.

## When one working tree becomes two PRs

Both of these bit on 2026-08-21, splitting one dirty tree into #43 and #44.

**`cp` is aliased to `cp -i` on this machine** — `~/.zshrc:372`, Home Manager
generated. In a non-interactive Bash call it answers its own prompt, prints
`not overwritten`, and **exits 0**. The copy does not happen and the output
reads like success. `mv`, `rm` and `ln` are not aliased; only `cp`. When
restoring saved file states to reconstruct a branch, use `cat src > dst` or
`command cp`. This was caught by the staged diff coming back empty, not by
anything the copy said — `lessons-learned.md` §1, a tool reporting success
while being wrong.

Note the alias is written `alias -- cp='cp -i'`, so a grep for `alias cp=`
misses it. That is how it went unnoticed the first time.

**A stacked PR is not retargeted when its base merges.** GitHub retargets a
child PR only when the base *branch is deleted*. So after the parent merges,
the child still points at a merged branch, and the obvious way to unblock it is
to delete that branch — which is step 4, and would mean the mechanics forcing a
confirmation that is supposed to be Elly's. Retarget explicitly instead, before
merging the child:

```sh
gh pr edit <child-number> --base main
```

Then merge it, then ask about both branches together at step 4.

**Both gates still apply per PR, but they can share a round-trip.**
`AskUserQuestion` takes up to four questions in one call, so two PRs is one call
with two merge questions, then one call with the branch-deletion question. That
is still a separate question per decision — which is the requirement — without
four round-trips. Say in the options which PR is stacked on which, so a
"no on the parent, yes on the child" answer is visibly incoherent rather than
something you have to unpick afterwards.

## The ruleset does not enforce this for you

A branch ruleset ("main: require a PR", id 21163726) was added 2026-08-21:
`main` cannot be deleted, cannot be force-pushed, and needs a PR to merge into.
Zero approvals are required, so Elly can merge their own PRs — requiring one on
a solo repo would deadlock, since nobody can approve their own.

**It does not stop you.** Bypass is granted to the admin repository role, and
`gh`/`git` here authenticate as Elly, who is the admin — the API reports
`current_user_can_bypass: always`. A direct `git push origin main` from this
session would still succeed. The ruleset is a backstop for everything else and
a visible statement of intent; the actual guard against the mistake this file
documents is this file. Do not read "main is protected" as "the tooling will
catch me".

## Only when Elly names main

The one exception is Elly specifically saying `main` for that push. A bare
"push", "ship it", or "land this" is not that.
