# `flake.lock` updates

_Last modified: 2026-09-16_

How this repo's nixpkgs pin moves: a weekly automated bump opens a PR, and
only a reviewed merge lands it — the lock diff is the review, because an
input bump can change what hosts build and boot, including the two that
wipe `/root` at every boot. The bump ran on a GitHub Actions runner from
2026-09-08 to 2026-09-16 (`.github/workflows/update-flake-lock.yml`, since
deleted) and now runs as cube's `flake-lock-bump` timer (#205) — same
Monday 09:00 UTC slot, same `update_flake_lock_action` branch, same PR, but
the update is **built** on real hardware before the PR is proposed, where
the runner could only evaluate it (§§36–37).

## Contents

- [The weekly run, today](#the-weekly-run-today)
- [Where the GitHub credential lives](#where-the-github-credential-lives)
- [History](#history)
- [See also](#see-also)
## The weekly run, today

`flake-lock-bump.timer` on cube (config: [lock-bump.md](categories/lock-bump.md)):
preflight the credential → `nix flake update` → `nix flake check` + module
tree + lint → **build nire-cube's toplevel** → commit the lock (synthetic
identity `nire-cube lock-bump`), force-push `update_flake_lock_action`,
open `chore: update flake.lock` against `experimental`. Merging follows the
normal ship flow. CI still only *evaluates* the PR, and only cube's toplevel
was built — durandal and tenacity deserve a real `just build`/`switch`
before a lock PR merges.

By hand: `just update` (`nix flake update`, then `just check`).

## Where the GitHub credential lives

The pushes and the PR authenticate as **elly's existing `gh auth` login on
cube** — the OAuth token in `~/.config/gh/hosts.yml` (`repo`, `workflow`
scopes; `push: true` on this repo, verified 2026-09-16). The script reads it
with `gh auth token` (an `$FLAKE_LOCK_TOKEN` env override exists for
testing); both units run as `User = "elly"` with `HOME` set explicitly.
There is no sops key, no dedicated PAT, and nothing minted for this — the
cutover (#205, 2026-09-16) deliberately consumed a credential the box
already had over minting and storing a second one. Rotation story: no
expiry, so the weekly preflight's early warning degrades to "cannot tell"
(a logged notice, not a failure — the same best-effort gap the workflow
documented); the login only breaks if it is removed, and then the run fails
loudly at the preflight and `OnFailure=` files the reusable issue
`update-flake-lock: weekly lock PR needs attention`.

Before the cutover, the credential was the `FLAKE_LOCK_TOKEN` Actions
secret — a fine-grained PAT (write-only: GitHub never lets a value be read
back), minted 2026-09-13, updated 2026-09-14, expiry 2027-09-12, proven
working by lock PRs [#308](https://github.com/NireBryce/nixos-configs/pull/308)
and [#333](https://github.com/NireBryce/nixos-configs/pull/333) both merging. That secret
is obsoleted by the timer: delete it after cube's first successful run.
Expiry/rotation bookkeeping lives in
[maintenance-schedule.md](maintenance-schedule.md) item 10.

## History

The Actions era took three commits to work: `0e533ac9` opened no PR at all
(GITHUB_TOKEN and the repo-wide create/approve setting), `fc0145d2` leaned
on that setting and was reverted for it, `6fe9fb5c` took the PAT route and
made expiry fail loudly. First success 2026-09-13/14 (#308); issue #219
tracked the mint-store-verify loop. #205 moved the job to cube because the
runner could never build; the credential moved with it, to what the box
already had.

## See also

- [lock-bump.md](categories/lock-bump.md) — the timer's configuration page.
- [maintenance.md](maintenance.md) "Lockfile updates" — the run story in
  the upkeep context.
- [maintenance-schedule.md](maintenance-schedule.md) item 10 — the
  credential's ledger entry.
