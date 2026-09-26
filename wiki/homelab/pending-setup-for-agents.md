# Pending setup, for agents

_Last modified: 2026-09-25_

Condensed from [pending-setup.md](pending-setup.md), which keeps the closed
items and their full accounts. Open work and the traps only here.

Scope: one-time operational work on a **live** service — a browser or ssh,
never `flake/modules/`. No commit can complete it; it lives in a service's
own database. The repo-side counterpart is
[open-threads.md](../open-threads.md).

## Still open

1. ~~**Forgejo SSH key.**~~ **Done 2026-09-13** — auth and a real clone over
   SSH confirmed from tenacity with `~/.ssh/id_ed25519`; push still
   untested. (`elly` *is* admin — confirmed 2026-09-12; the API below still
   cannot show it.) Procedure, for the next one:
   [forgejo.md](forgejo.md#adding-one). The key is **yours**, not the
   `forgejo` account's; that account has no keypair. Formerly: add a key for
   `forgejo@ts-cube:…` clones ([forgejo.md](forgejo.md) explains why that
   key authorizes `forgejo@ts-cube`, not `elly@ts-cube`).
2. **golink has no links.** `http://go/.export` returns empty. Proposed
   first three:

   | Short | Target |
   |---|---|
   | `go/dash` | `https://homepage.moose-micro.ts.net/` |
   | `go/git` | `https://git.moose-micro.ts.net/` |
   | `go/graf` | `https://grafana.moose-micro.ts.net/` |

   Create in the web UI at `http://go/`, or the `curl` form in
   [creating-golinks.md](creating-golinks.md) — **read that page's `--post302` and delete
   traps first, both have teeth.** Done when `go/dash` resolves from a
   *second* tailnet device.
3. ~~**Grafana admin credentials**~~ **Done 2026-09-13.** Live password
   changed by hand (UI); persists in cube's sqlite db, not reproducible.
   Separately `grafana.nix` now sets `settings.security.admin_password`
   from the `grafana-admin-password` sops secret — **first start only**
   (Grafana `defaults.ini`: "can be changed before first start"), so it
   stops a rebuilt instance coming up on stock `admin`/`admin` but does
   not manage the live password. **Switched 2026-09-13**: secret present as `grafana:grafana` 400, live
   `config.ini` references it, unit active `NRestarts=0`. **Never
   consumed** — the admin user predates it, so only a fresh instance
   would read it.
4. **Homepage's calendar feeds** (#291, 2026-09-12) — plumbing all landed;
   the gcal **secret iCal addresses** don't exist yet (IDs deliberately
   unassigned). Until filled in the calendars render bare-grid + empty
   agenda, plus a small API-error band per card (the placeholder URL
   403ing) — **by design, not a bug**. Fill-in: edit sops key
   `homepage-env` (a systemd EnvironmentFile), one
   `HOMEPAGE_VAR_ICAL_<NAME>=<secret-ics-url>` line per calendar; add a
   `calendars` entry in `homepage.nix` for each new NAME. Details:
   [../categories/landing.md](../categories/landing.md#how-the-gcal-calendar-feeds-work).
5. **Forgejo Actions runner** (guest `forge-runner` in a libvirt VM on
   cube since 2026-09-25): secret + UUID **landed 2026-09-25** (the
   2026-09-24 build gate is gone — the tree builds; guest image + cube
   toplevel both build). What remains: `just build` + `just switch` on
   cube, then the done-when: `forgejo-runner-registration.service` and
   `libvirt-vm-forge-runner.service` succeeded, guest running (debug SSH:
   `ssh -t ts-cube ssh root@192.168.122.11`, cube's key only), runner shows
   `forge-runner`/`Idle` in Site Administration → Actions → Runners, and a
   workflow run goes green. Egress check from inside the guest: forge 443
   answers; LAN/tailnet addresses time out (guest-local OUTPUT rules). Rotation = new `forgejo-runner-secret` → new
   derived UUID pinned in the guest config → delete the orphaned runner
   row. Original fill-in procedure:
   [pending-setup.md](pending-setup.md#8-forgejo-actions-runner-secret-and-uuid).

## The trap that produced a wrong answer twice

**Unauthenticated `GET /git/api/v1/users/search` masks fields.** It always
returns `last_login` as `0001-01-01T00:00:00Z` and `is_admin`/`active` as
`false`, regardless of the truth — Forgejo/Gitea's anonymous-safe masking.
Two agent sessions (2026-09-04, 2026-09-05) read that zero value as "nobody
has signed in yet" and wrote it into this page *and* the backup runbook.
Both wrong: a same-day screenshot showed an active session throughout. The
endpoint cannot answer either question. It was settled the only way it
could be — from inside the UI: **`elly` is admin, confirmed by the user
2026-09-12.** The masked `is_admin: false` was never evidence either way.
Full account: [../categories/git-forge-history.md](../categories/git-forge-history.md).

## Done, but load-bearing to know

- **Backups work and a real restore has recovered a complete Forgejo
  database** (2026-09-06, issue #87). The restore drill found that
  `backupPrepareCommand`'s sqlite staging had *never* worked — see
  [../categories/backup-for-agents.md](../categories/backup-for-agents.md).
- **This repo is a Forgejo pull mirror**, not an origin — `elly/nixos-configs`,
  `mirror_interval: 8h0m0s`, authenticated with the `forgejo_api_key` sops
  secret. GitHub stays canonical; no cron in this repo. **Settled** — mirror
  reaffirmed 2026-09-12 with backups proven; not an open question.
- **A Grafana dashboard edited in the UI lives only in cube's sqlite db.**
  Backed up, so it survives a *restore* — but not a *rebuild* that
  reprovisions `_dashboards/`.

## See also

[pending-setup.md](pending-setup.md) ·
[reaching-services-for-agents.md](reaching-services-for-agents.md) ·
[creating-golinks-for-agents.md](creating-golinks-for-agents.md) ·
[backup-runbook-for-agents.md](backup-runbook-for-agents.md)
