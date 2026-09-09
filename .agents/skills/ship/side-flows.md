# ship — side flows

Companion to `SKILL.md`, which links here for everything that isn't the
ordinary push → PR → merge-and-delete flow. Each section stands alone.

## The ruleset picture (trunk + promotion, 2026-09-03)

Two rulesets, both enforced by GitHub:

- **`experimental` (the default branch)** — the ruleset added for `main`
  2026-08-21 targets `~DEFAULT_BRANCH`, so it followed the default-branch
  flip automatically: no deletion, no force-push, PR required (zero
  approvals — solo repo), CI check required. The single conversational
  confirmation remains the guard on *top* of this — it gates the
  merge-and-delete decision, the ruleset gates everything else.
- **`main` (promoted known-good)** — protected by name: same rules. It
  moves only via a PR from `experimental` (the promotion flow below), and
  only for configs verified on hardware.

## Promoting to `main`

On a "promote to main"-shaped ask (not part of the ordinary flow in
`SKILL.md`):

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

## When one working tree becomes two PRs

Both bit 2026-08-21 (#43/#44):

- **`cp` is aliased `cp -i` here** (`~/.zshrc`, HM-generated). Non-interactive,
  it answers its own prompt and **exits 0 without copying**. Use `cat src >
  dst` or `command cp` when reconstructing file states. (Written `alias --
  cp='cp -i'`, so `grep 'alias cp='` misses it.) Caught by an empty staged
  diff, not by anything the copy said — §1, a tool reporting success while
  wrong.
- **A stacked PR is not retargeted when its base merges** (only when the base
  *branch is deleted*, which now happens automatically right after merge —
  there's no longer a gap between merge and delete to catch it in). Retarget
  explicitly *before* merging the base: `gh pr edit <child> --base
  experimental`. Each PR still gets its own merge-and-delete confirmation,
  but a harness can batch several such questions into one call — still one
  question per decision. Name which PR is stacked on which, so an
  incoherent answer is visibly incoherent.

## Only when Elly names a branch

Elly naming a branch outright for that push — any branch except `main`,
which is promotion-only (see above). A bare "push" is not that; it means
the guarded flow in `SKILL.md`, onto `experimental`.
