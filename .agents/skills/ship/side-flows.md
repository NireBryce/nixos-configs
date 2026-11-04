# ship — side flows

Companion to `SKILL.md`. It covers everything outside the ordinary push → PR → merge-and-delete flow. Each section stands alone.

## The ruleset picture (trunk + promotion, 2026-09-03)

Two GitHub-enforced rulesets apply:

- **`experimental` (default branch)**: the ruleset added for `main` on 2026-08-21 targets `~DEFAULT_BRANCH`, so it followed the default-branch flip. It forbids deletion and force-push, requires a PR (zero approvals, solo repo), and requires the CI check. The conversational confirmation is a guard on top: it gates merge-and-delete, and the ruleset gates the rest.
- **`main` (promoted known-good)**: protected by name, with the same rules. It moves only via a PR from `experimental` (below), and only for configs verified on hardware.

## Promoting to `main`

On a "promote to main" ask:

```sh
gh pr create --base main --head experimental \
  --title "promote: <one line on what's verified>" \
  --body "what landed since the last promotion, and where it was booted/switched"
gh pr merge <n> --merge     # a merge commit -- never --rebase
```

The PR records why `main` moved: write what was verified on hardware, not just the commit range. Promote only after the config has booted or switched on the hosts it touches.

**Merge, never rebase.** This section prescribed `--rebase` from 2026-09-03, but no promotion used it: #201 (2026-09-08) and #354 (2026-09-15) merged. Rebase gives every promoted commit a new SHA on `main`, so `main..experimental` counts them as unpromoted forever and parity checks need patch-id machinery. A merge commit made `main..experimental` read as exactly the commits since the last promotion after #354.

## When one working tree becomes two PRs

Both of these happened 2026-08-21 (#43/#44):

- **`cp` is aliased `cp -i`** (`~/.zshrc`, HM-generated; written `alias -- cp='cp -i'`, so `grep 'alias cp='` misses it). Without a terminal, it answers its own prompt and exits 0 without copying. Use `cat src > dst` or `command cp`. An empty staged diff caught it, not the copy (§1, a tool reporting success while wrong).
- **A stacked PR is retargeted only when its base branch is deleted**, not when the base merges. Branch deletion is now automatic right after merge, so there is no gap to catch it in. Retarget before merging the base: `gh pr edit <child> --base experimental`. Each PR still gets its own merge-and-delete confirmation (a harness may batch the questions, but there is still one per decision). Name which PR is stacked on which.

## Only when the user names a branch

When the user names a branch outright for a push, push directly there. Any branch except `main` qualifies (`main` is promotion-only). A bare "push" does not count; it means the guarded flow in `SKILL.md`, onto `experimental`.
