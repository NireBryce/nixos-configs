# Maintenance schedule, for agents

_Last modified: 2026-10-30_

_Sibling reviewed: 2026-10-20 -- source trimmed of rationale narration (items 10, 12, intro); no item facts changed. Earlier (2026-10-01): source's restic rotation-log link repointed from pending-setup.md to backup-history.md; this page carries no such link_

Condensed from [maintenance-schedule.md](maintenance-schedule.md). Tended by
skill [`maintenance-schedule`](../../.agents/skills/maintenance-schedule/SKILL.md).

Scope: credentials with a real expiry, rotation cadence, or silent-breakage
property. Not an inventory of `secrets.yaml`. Plaintext on purpose — names
and dates are not values.

## Items

| # | Item | Expiry / cadence | Fails how | Last checked |
|---|---|---|---|---|
| 1 | `tailscale_key` | 90d max; already stale | **nothing** — undeclared and unused | 2026-09-07 |
| 2 | `tailscale_api_token` | **unverified** (classic PAT 90d; OAuth secret never) | `tailscale-acl.py get`/`apply`/`vip-*` silently start 401ing | 2026-09-07 |
| 3 | Tailscale node keys | 180d default, per machine | host drops off the tailnet until interactive `tailscale up` | 2026-09-07 |
| 4 | sops age recipients (host keys on `secrets.yaml`; user keys on `low-side/` only) | none on a timer | a regenerated SSH host key silently orphans that host | 2026-10-22 (structure only) |
| 5 | `restic-cube-ssh-key` / `restic-cube-password` | on suspicion / `ts-hive` re-image | backup runs fail | 2026-08-31 |
| 6 | `ts-hive` SSH host key pin | none; breaks on re-image | backup runs fail | untracked |
| 7 | `forgejo-admin-password` | none enforced; never rotated | — | — |
| 8 | Grafana admin credentials | real password, set by hand 2026-09-13; **not** reproducible | lives only in cube's sqlite db | 2026-09-13 |
| 9 | Syncthing device certs | decades; declared by no module since 2026-09-08, **`syncthing-*` keys removed from `secrets.yaml` 2026-10-19** (`842b216a`) | nothing; stub | 2026-10-22 |
| 10 | `FLAKE_LOCK_TOKEN` | expires 2027-09-12; custom date ≤366d | fails loudly by construction, see below | 2026-09-13 |
| 11 | Atuin account key (undeclared `atuin_key` entry in `secrets.yaml`: same key unconfirmed) | none; on suspicion only | — | 2026-09-09 |
| 12 | `nire-galatea/tskey` (git history only) | dead — rotated 2024; auth keys ≤90d anyway | nothing — history fossil, not a credential | 2026-09-14 |
| 13 | `cube_claude_rc_github_token` | fine-grained PAT, expires **2027-01-28** (GitHub header, 2026-10-30) | pushes from cube's `claude-rc` sessions get an auth error; nothing else | 2026-10-30 |

**Row 12, decided not pended.** Auth key committed 2024-01-29 (`449d158`)
for the removed `nire-galatea`; left in git history deliberately (rewrite
rejected 2026-09-14: public repo, window closed, force-push of both protected
branches too costly). Scanner flags it: mark rotated/false-positive, move on.

**Row 13.** Fine-grained PAT, repos in `claude-rc-cube.nix`'s `dirs`, Contents r/w only; sops-declared on
cube, `LoadCredential` into each `claude-rc-*` unit, git helper in the unit's
`GIT_CONFIG_*`. Rotate: new PAT, `sops` edit of the value, switch cube,
`systemctl --user restart 'claude-rc-*'`. Account-wide `gh` token stays
unbound from the units on purpose.

**Row 8.** Live password set by hand 2026-09-13, only in cube's sqlite db.
Separately `grafana-admin-password` (sops) feeds
`settings.security.admin_password`, applied **at first start only** (stops a
rebuilt instance coming up on stock `admin`/`admin`); it does not manage the
live password. Deployed, checked on cube 2026-09-13 (`grafana:grafana` 400,
in live `config.ini`, unit clean) but **never consumed**: admin user
predates it. `grafana-cli admin reset-admin-password` per activation would
unify them; deliberately not done.

**Rule:** default credentials are a *live* credential with a published
password, never "not set up yet"; the *absence* of an `admin_password`
setting is what leaves it stock. Skill `maintenance-schedule` has the row
shape.

## The rows with a live action attached

- **#2** — go find out which kind of token it is
  (`login.tailscale.com/admin/settings/keys`) and record it.
- **#3** — `nire-durandal` has expiry disabled. **`nire-cube` does not, and
  expires 2027-02-18** — it is the one host running unattended services, so
  a silent lapse takes every service with it. `nire-lysithea` appears
  **twice**, both offline, two different expiry dates: a stale duplicate
  registration worth pruning. Read live with `tailscale status --json`.

## Procedures live elsewhere

| Item | Where |
|---|---|
| 4 | `just age-key` → update `.sops.yaml` → `sops updatekeys secrets.yaml`; [../config-structure/impermanence-and-secrets.md](../config-structure/impermanence-and-secrets.md) |
| 5, 6 | [../homelab/backup-runbook.md](../homelab/backup-runbook.md) |
| 11 | `packages-config/shell-apps/history/atuin-key-rotation.md` |

## `FLAKE_LOCK_TOKEN` specifics

Minted 2026-09-13, expires 2027-09-12. Verified end to end same day:
manual `workflow_dispatch` passed preflight and opened #308.

GitHub Actions repo secret, **not** `secrets.yaml` (runner has no host key to
enrol; `secrets.yaml` is in a public repo). A PAT, not `GITHUB_TOKEN`:
`GITHUB_TOKEN`-opened PRs don't trigger `pull_request` workflows, which the
`experimental` ruleset requires.

Self-check: missing/revoked/expired -> hard fail (`::error::`) at first step
plus an issue in this repo (reuses one titled `update-flake-lock: weekly lock
PR needs attention`). Within 30 days of expiry -> `::warning::`, continues.
**Gap**: GitHub sends the expiry header only for tokens that have one; absent
header = `::notice::`, no fail.

Lapse symptom to recognise: the `update_flake_lock_action` branch sitting
ahead of `experimental` with no PR attached.

## Adding an item

In the same change that introduces the credential. No expiry, cadence, or
silent-breakage property -> it just lives in `secrets.yaml`.

See also: [../homelab/pending-setup.md](../homelab/pending-setup.md) (one-time
setup).
