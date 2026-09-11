# Pending setup, for agents

_Last modified: 2026-09-11_

Condensed from [pending-setup.md](pending-setup.md), which keeps the closed
items and their full accounts. Open work and the traps only here.

Scope: one-time operational work on a **live** service — a browser or ssh,
never `flake/modules/`. No commit can complete it; it lives in a service's
own database. The repo-side counterpart is
[open-threads.md](../open-threads.md).

## Still open

1. **Forgejo: is `elly` really admin?** `forgejo-admin-bootstrap` passes
   `--admin`, but nothing has confirmed it took. Check the **Site
   Administration panel from inside the UI** — see the API trap below.
   Separately, add an SSH key under Settings → SSH keys for
   `forgejo@ts-cube:…` clones ([forgejo.md](forgejo.md) explains why that
   key authorizes `forgejo@ts-cube`, not `elly@ts-cube`).
2. **golink has no links.** `http://go/.export` returns empty. Proposed
   first three:

   | Short | Target |
   |---|---|
   | `go/dash` | `https://glance.moose-micro.ts.net/` |
   | `go/git` | `https://git.moose-micro.ts.net/` |
   | `go/graf` | `https://grafana.moose-micro.ts.net/` |

   Create in the web UI at `http://go/`, or the `curl` form in
   [golinks.md](golinks.md) — **read that page's `--post302` and delete
   traps first, both have teeth.** Done when `go/dash` resolves from a
   *second* tailnet device.
3. **Grafana admin credentials** — ships a default `admin` account and
   prompts for a change on first sign-in. Not verifiable without logging in;
   confirm it happened. The tailnet is the only thing in front of it.

## The trap that produced a wrong answer twice

**Unauthenticated `GET /git/api/v1/users/search` masks fields.** It always
returns `last_login` as `0001-01-01T00:00:00Z` and `is_admin`/`active` as
`false`, regardless of the truth — Forgejo/Gitea's anonymous-safe masking.
Two agent sessions (2026-09-04, 2026-09-05) read that zero value as "nobody
has signed in yet" and wrote it into this page *and* the backup runbook.
Both wrong: a same-day screenshot showed an active session throughout. The
endpoint cannot answer either question.

## Done, but load-bearing to know

- **Backups work and a real restore has recovered a complete Forgejo
  database** (2026-09-06, issue #87). The restore drill found that
  `backupPrepareCommand`'s sqlite staging had *never* worked — see
  [../categories/backup-for-agents.md](../categories/backup-for-agents.md).
- **This repo is a Forgejo pull mirror**, not an origin — `elly/nixos-configs`,
  `mirror_interval: 8h0m0s`, authenticated with the `forgejo_api_key` sops
  secret. GitHub stays canonical; no cron in this repo. Worth revisiting now
  that a restore is proven, if an origin is wanted.
- **A Grafana dashboard edited in the UI lives only in cube's sqlite db.**
  Backed up, so it survives a *restore* — but not a *rebuild* that
  reprovisions `_dashboards/`.

## See also

[pending-setup.md](pending-setup.md) ·
[reaching-services-for-agents.md](reaching-services-for-agents.md) ·
[golinks-for-agents.md](golinks-for-agents.md) ·
[backup-runbook-for-agents.md](backup-runbook-for-agents.md)
