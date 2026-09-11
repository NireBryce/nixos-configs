# Maintenance schedule, for agents

_Last modified: 2026-09-11_

Condensed from [maintenance-schedule.md](maintenance-schedule.md), which
keeps each item's reasoning, rejected alternatives and evidence. Facts only
here. Tended by skill
[`maintenance-schedule`](../.agents/skills/maintenance-schedule/SKILL.md).

Scope: credentials with a real expiry, rotation cadence, or silent-breakage
property. Not an inventory of `secrets.yaml`. Plaintext on purpose — names
and dates are not values.

## Items

| # | Item | Expiry / cadence | Fails how | Last checked |
|---|---|---|---|---|
| 1 | `tailscale_key` | 90d max; already stale | **nothing** — undeclared and unused | 2026-09-07 |
| 2 | `tailscale_api_token` | **unverified** (classic PAT 90d; OAuth secret never) | `tailscale-acl.py get`/`apply`/`vip-*` silently start 401ing | 2026-09-07 |
| 3 | Tailscale node keys | 180d default, per machine | host drops off the tailnet until interactive `tailscale up` | 2026-09-07 |
| 4 | sops age recipients | none on a timer | a regenerated SSH host key silently orphans that host | 2026-09-07 |
| 5 | `restic-cube-ssh-key` / `restic-cube-password` | on suspicion / QNAP re-image | backup runs fail | 2026-08-31 |
| 6 | QNAP SSH host key pin | none; breaks on re-image | backup runs fail | untracked |
| 7 | `forgejo-admin-password` | none enforced; never rotated | — | — |
| 8 | Grafana admin credentials | **still on initial setup** | — | 2026-09-07 |
| 9 | Syncthing device certs | decades; **declared by no module since 2026-09-08** | nothing | 2026-09-07 |
| 10 | `FLAKE_LOCK_TOKEN` | fine-grained PAT, **must** carry one (366d max) | fails loudly by construction, see below | 2026-09-08 |
| 11 | Atuin account key | none; on suspicion only | — | 2026-09-09 |

## The rows with a live action attached

- **#2** — go find out which kind of token it is
  (`login.tailscale.com/admin/settings/keys`) and record it.
- **#3** — `nire-durandal` has expiry disabled. **`nire-cube` does not, and
  expires 2027-02-18** — it is the one host running unattended services, so
  a silent lapse takes every service with it. `nire-lysithea` appears
  **twice**, both offline, two different expiry dates: a stale duplicate
  registration worth pruning. Read live with `tailscale status --json`.
- **#10** — **the secret did not exist yet as of 2026-09-08**; until it
  does, every weekly run fails at preflight.

## Procedures live elsewhere

| Item | Where |
|---|---|
| 4 | `just age-key` → update `.sops.yaml` → `sops updatekeys secrets.yaml`; [impermanence-and-secrets.md](impermanence-and-secrets.md) |
| 5, 6 | [homelab/backup-runbook.md](homelab/backup-runbook.md) |
| 11 | `nirePackages/shell-apps/history/atuin-key-rotation.md` |

## `FLAKE_LOCK_TOKEN` specifics

GitHub Actions repo secret, **not** `secrets.yaml` — a runner has no
persistent host key to enrol, and `secrets.yaml` is committed to a public
repo. A PAT rather than `GITHUB_TOKEN` because a `GITHUB_TOKEN`-opened PR
does not trigger `pull_request` workflows, and the `experimental` ruleset
requires that check.

The workflow checks its own credential: missing/revoked/expired → hard fail
with a `::error::` at the first step, plus an issue opened in this repo
(reusing one titled `update-flake-lock: weekly lock PR needs attention`).
Within 30 days of expiry → `::warning::`, keeps going. **Gap**: GitHub
returns the expiry header only for tokens that have one, so an absent header
means "cannot tell" — that emits a `::notice::` and does not fail.

Lapse symptom to recognise: the `update_flake_lock_action` branch sitting
ahead of `experimental` with no PR attached.

## Adding an item

Same change that introduces the credential. A secret with no expiry,
cadence, or silent-breakage property doesn't belong here — it just lives in
`secrets.yaml`.

## See also

[maintenance-schedule.md](maintenance-schedule.md) · skill
[`secrets-hygiene`](../.agents/skills/secrets-hygiene/SKILL.md) ·
[homelab/pending-setup.md](homelab/pending-setup.md) (one-time setup, as
opposed to recurring)
