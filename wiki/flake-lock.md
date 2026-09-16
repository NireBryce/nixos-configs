# `flake.lock` updates

_Last modified: 2026-09-16_

How this repo's nixpkgs pin moves: a weekly automated bump opens a PR, and
only a reviewed merge lands it — the lock diff is the review, because an
input bump can change what hosts build and boot, including the two that
wipe `/root` at every boot. The bump is the
[DeterminateSystems/update-flake-lock](https://github.com/DeterminateSystems/update-flake-lock)
GitHub Action, SHA-pinned like every third-party action here, running
Mondays 09:00 UTC plus on-demand `workflow_dispatch`.

## Contents

- [The weekly run](#the-weekly-run)
- [Where the GitHub credential lives](#where-the-github-credential-lives)
- [Explored, not shipped: building on cube before proposing](#explored-not-shipped-building-on-cube-before-proposing)
- [History](#history)
- [See also](#see-also)
## The weekly run

`.github/workflows/update-flake-lock.yml` checks out `experimental`
explicitly — the trunk landing target; `main` is promotion-only — runs
`nix flake update` through the action, pushes the `update_flake_lock_action`
branch, and opens a `chore: update flake.lock` PR against `experimental`.
Before anything else it preflights the credential against the GitHub API:
a missing, revoked, or expired token hard-fails the run before any nix
work; a token within 30 days of expiry warns and keeps going. Either case
lands in a reusable issue titled `update-flake-lock: weekly lock PR needs
attention`, because a red scheduled run only emails the repo owner.

The PR is a decision, not an auto-merge. CI (`nix flake check + module
tree`) *evaluates* every host toplevel on the PR, but nothing builds it —
`just preflight` plus a real `just build`/`switch` on the affected hosts is
the stronger check before merging. See §§36–37 of
[lessons-learned.md](lessons-learned.md) for why that distinction keeps
earning its keep.

By hand: `just update` (`nix flake update`, then `just check`).

## Where the GitHub credential lives

The repo secret **`FLAKE_LOCK_TOKEN`** — a fine-grained PAT scoped to this
repo (`Contents: read/write`, `Pull requests: read/write`). A PAT, not
`GITHUB_TOKEN`, for three reasons recorded in the workflow's own header: a
`GITHUB_TOKEN`-opened PR does not trigger this repo's `pull_request`
workflows and the `experimental` ruleset requires them; the repo-wide
"Allow GitHub Actions to create and approve pull requests" switch stays
off; and the token structurally cannot approve its own PRs. Being an
Actions secret, it is write-only — GitHub never lets the value be read
back, so rotation means minting a new one and re-setting the secret. It was
minted 2026-09-13 and updated 2026-09-14, expiry **2027-09-12**, proven
working end to end by lock PRs
[#308](https://github.com/NireBryce/nixos-configs/pull/308) and
[#333](https://github.com/NireBryce/nixos-configs/pull/333) both merging.
Expiry and rotation bookkeeping:
[maintenance-schedule.md](maintenance-schedule.md) item 10.

## Explored, not shipped: building on cube before proposing

[#205](https://github.com/NireBryce/nixos-configs/issues/205) proposed
moving this job to a timer on cube so the bump would be **built** on real
hardware before its PR was opened — the runner can only evaluate. It was
implemented fully in 2026-09-16 (a `flake-lock-bump` timer, its own
`homelab/lock-bump/` category, authentication via elly's existing `gh`
login on cube) and reverted the same day, before cube ever switched onto
it: the fleet stayed on the hosted action. The closing comment on #205 has
the exploration summary; the work itself is in git history at merge
`e887d55b` (reverted by `ea8d78c1`). The one verified finding worth
keeping: building cube's own toplevel before proposing is mechanically
trivial whenever it's wanted — nothing about the hosted workflow prevents
a human running `just build` after a lock PR appears, which remains the
stronger check this page already recommends.

## History

Three commits to make the workflow work: `0e533ac9` opened no PR at all
(GITHUB_TOKEN plus the repo-wide create/approve setting), `fc0145d2` leaned
on that setting and was reverted for it, `6fe9fb5c` took the PAT route and
made expiry fail loudly. First success 2026-09-13/14 (#308); issue #219
tracked the mint-store-verify loop.

## See also

- [maintenance.md](maintenance.md) "Lockfile updates" — the run story in
  the upkeep context.
- [maintenance-schedule.md](maintenance-schedule.md) item 10 — the
  credential's ledger entry.
