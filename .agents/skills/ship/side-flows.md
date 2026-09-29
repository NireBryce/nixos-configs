# ship — side flows

Companion to `SKILL.md`; everything that isn't the ordinary push → PR →
merge-and-delete flow. Each section stands alone.

## The ruleset picture (trunk + promotion, 2026-09-03)

Two GitHub-enforced rulesets:

- **`experimental` (default branch)** — the ruleset added for `main`
  2026-08-21 targets `~DEFAULT_BRANCH`, so it followed the default-branch
  flip: no deletion, no force-push, PR required (zero approvals, solo repo),
  CI check required. The conversational confirmation is a guard on top: it
  gates merge-and-delete, the ruleset gates the rest.
- **`main` (promoted known-good)** — protected by name, same rules. Moves
  only via a PR from `experimental` (below), only for configs verified on
  hardware.

## Promoting to `main`

On a "promote to main"-shaped ask:

```sh
gh pr create --base main --head experimental \
  --title "promote: <one line on what's verified>" \
  --body "what landed since the last promotion, and where it was booted/switched"
gh pr merge <n> --merge     # a merge commit -- never --rebase
```

The PR records *why* `main` moved: write what was verified on hardware, not
just the commit range. Promote only after the config has booted/switched on
the hosts it touches.

**Merge, never rebase.** This section prescribed `--rebase` from 2026-09-03;
no promotion ever used it — #201 (2026-09-08) and #354 (2026-09-15) merged.
Rebase gives every promoted commit a new SHA on `main`, so `main..experimental`
counts them unpromoted forever and parity checks need patch-id machinery; a
merge commit made `main..experimental` read as exactly
commits-since-last-promotion after #354.

## When one working tree becomes two PRs

Both bit 2026-08-21 (#43/#44):

- **`cp` is aliased `cp -i`** (`~/.zshrc`, HM-generated; written `alias --
  cp='cp -i'`, so `grep 'alias cp='` misses it). Non-interactive, it answers
  its own prompt and **exits 0 without copying**. Use `cat src > dst` or
  `command cp`. Caught by an empty staged diff, not by the copy — §1, a tool
  reporting success while wrong.
- **A stacked PR is retargeted only when its base *branch is deleted*** (now
  automatic right after merge — no gap to catch it in), not when the base
  merges. Retarget *before* merging the base: `gh pr edit <child> --base
  experimental`. Each PR still gets its own merge-and-delete confirmation
  (a harness may batch the questions — still one per decision). Name which
  PR is stacked on which.

## Only when the user names a branch

The user names a branch outright for that push — any branch except `main`
(promotion-only). A bare "push" is not that; it means the guarded flow in
`SKILL.md`, onto `experimental`.
