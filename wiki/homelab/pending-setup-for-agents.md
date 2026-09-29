# Pending setup, for agents

_Last modified: 2026-09-29_

Condensed from [pending-setup.md](pending-setup.md). Open work and traps only.

Scope: one-time operational work on a **live** service (browser/ssh, never
`flake/modules/`); lives in the service's own database. Repo-side
counterpart: [open-threads.md](../open-threads.md).

## Still open

1. ~~**Forgejo SSH key.**~~ **Done 2026-09-13** — auth and real clone over
   SSH confirmed from tenacity with `~/.ssh/id_ed25519`; push untested.
   `elly` *is* admin (2026-09-12). Next key: [forgejo.md](forgejo.md#adding-one);
   the key is the user's, not the `forgejo` account's (no keypair).
2. **golink has no links.** `http://go/.export` returns empty. Proposed
   first three:

   | Short | Target |
   |---|---|
   | `go/dash` | `https://homepage.moose-micro.ts.net/` |
   | `go/git` | `https://git.moose-micro.ts.net/` |
   | `go/graf` | `https://grafana.moose-micro.ts.net/` |

   Create in the web UI at `http://go/`, or the `curl` form in
   [creating-golinks.md](creating-golinks.md) — **read its `--post302` and
   delete traps first.** Done when `go/dash` resolves from a *second* tailnet
   device.
3. ~~**Grafana admin credentials**~~ **Done 2026-09-13.** Live password set
   by hand, only in cube's sqlite db. `grafana.nix` sets
   `settings.security.admin_password` from sops `grafana-admin-password`,
   **first start only**: stops a rebuilt instance coming up on `admin`/`admin`,
   doesn't manage the live password. Switched 2026-09-13 (`grafana:grafana`
   400, in live `config.ini`, unit active `NRestarts=0`); **never consumed**
   (admin user predates it).
4. **Homepage's calendar feeds** (#291, 2026-09-12) — plumbing landed; gcal
   **secret iCal addresses** don't exist yet (IDs unassigned). Until filled:
   bare-grid calendars, empty agenda, small API-error band per card (placeholder
   URL 403ing) — **by design**. Fill-in: sops key `homepage-env`
   (EnvironmentFile), one `HOMEPAGE_VAR_ICAL_<NAME>=<secret-ics-url>` line per
   calendar, plus a `calendars` entry in `homepage.nix` per NAME. Details:
   [../categories/landing.md](../categories/landing.md#how-the-gcal-calendar-feeds-work).
5. ~~Forgejo Actions runner~~ — **done 2026-09-26** (first green run,
   `elly/nire-skills` run 2). Nothing to fill in: cube mints a single-use
   secret per job (`forge-runner-cycle`); sops `forgejo-runner-secret`
   removed. [pending-setup.md](pending-setup.md#8-done--forgejo-actions-runner-first-green-run-2026-09-26).

## Trap: unauthenticated `GET /git/api/v1/users/search` masks fields

Always returns `last_login` `0001-01-01T00:00:00Z` and `is_admin`/`active`
`false` regardless of truth. Two sessions (2026-09-04/05) misread it as
"nobody has signed in" and wrote it into this page and the backup runbook.
It answers neither question; settled from the UI: **`elly` is admin
(2026-09-12).** Anonymous calls stopped working 2026-09-26
(`REQUIRE_SIGNIN_VIEW`). Account:
[../categories/git-forge-history.md](../categories/git-forge-history.md).

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

See also: [reaching-services-for-agents.md](reaching-services-for-agents.md) ·
[creating-golinks-for-agents.md](creating-golinks-for-agents.md) ·
[backup-runbook-for-agents.md](backup-runbook-for-agents.md)
