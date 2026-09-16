# Maintenance schedule, for agents

_Last modified: 2026-09-16_

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
| 8 | Grafana admin credentials | real password, set by hand 2026-09-13; **not** reproducible | lives only in cube's sqlite db | 2026-09-13 |
| 9 | Syncthing device certs | decades; **declared by no module since 2026-09-08** | nothing | 2026-09-07 |
| 10 | elly's `gh auth` OAuth login on cube | no expiry; breaks only on `gh auth logout` | fails loudly by construction, see below | 2026-09-16 |
| 11 | Atuin account key | none; on suspicion only | — | 2026-09-09 |
| 12 | `nire-galatea/tskey` (git history only) | dead — rotated 2024; auth keys ≤90d anyway | nothing — history fossil, not a credential | 2026-09-14 |

**Row 12, decided not pended.** A Tailscale auth key committed 2024-01-29
(`449d158`) while the removed `nire-galatea` host still existed; left in
git history deliberately (rewrite rejected 2026-09-14: public repo, the
exposure window closed years ago, and the cost is force-pushing both
protected branches plus every SHA reference since January 2024). When a
scanner flags it: mark rotated/false-positive, move on — it is noise, not
a finding.

**Row 8, two independent things.** The live password was set by hand
2026-09-13 and exists only in cube's sqlite db. Separately,
`grafana-admin-password` (sops) feeds `settings.security.admin_password`,
which Grafana applies **at first start only** — it stops a rebuilt instance
coming up on stock `admin`/`admin`; it does not manage the live password.
Deployed and checked on cube 2026-09-13 (`grafana:grafana` 400, referenced
by the live `config.ini`, unit clean) but **never consumed**: the admin user
predates it.
`grafana-cli admin reset-admin-password` per activation is what would unify
them, and is deliberately not done.

**General rule this came from:** default credentials are a *live* credential
with a published password, never "not set up yet" — that wording misled a
reader 2026-09-13. A stock password is also invisible from the repo, since
the *absence* of an `admin_password` setting is what leaves it stock. Skill
`maintenance-schedule` has the required row shape.

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
| 4 | `just age-key` → update `.sops.yaml` → `sops updatekeys secrets.yaml`; [impermanence-and-secrets.md](impermanence-and-secrets.md) |
| 5, 6 | [homelab/backup-runbook.md](homelab/backup-runbook.md) |
| 11 | `packages/shell-apps/history/atuin-key-rotation.md` |

## Weekly-lock credential specifics

Since 2026-09-16 (#205): elly's `gh auth` OAuth login on cube
(`repo`/`workflow` scopes, `push: true` verified), read by
`lock-bump.sh` via `gh auth token` — no sops key, no dedicated PAT. The
FLAKE_LOCK_TOKEN Actions secret it replaced (fine-grained PAT,
2026-09-13/14, proven by lock PRs #308/#333) was write-only; delete it
after cube's first successful run. Trades accepted: `repo` is broader
than a repo-scoped PAT; no expiry, so the preflight's early warning
degrades to "cannot tell" (notice, not failure).

`lock-bump.sh` preflights every run: dead/rejected credential → hard
fail before any nix work; `OnFailure=` files the reusable issue
`update-flake-lock: weekly lock PR needs attention`. If the gh login is
gone entirely, the alert says so in the journal and files nothing.

Lapse symptom: `update_flake_lock_action` ahead of `experimental` with
no PR attached. Fix: `gh auth login` as elly on cube, rerun
`systemctl start flake-lock-bump`.

## Adding an item

Same change that introduces the credential. A secret with no expiry,
cadence, or silent-breakage property doesn't belong here — it just lives in
`secrets.yaml`.

## See also

[maintenance-schedule.md](maintenance-schedule.md) · skill
[`secrets-hygiene`](../.agents/skills/secrets-hygiene/SKILL.md) ·
[homelab/pending-setup.md](homelab/pending-setup.md) (one-time setup, as
opposed to recurring)
