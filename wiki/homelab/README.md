# Homelab services

_Last modified: 2026-09-12_

## Contents

- [Pages](#pages)
- [Also running, not yet written up](#also-running-not-yet-written-up)
- [Half-finished is the normal state here](#half-finished-is-the-normal-state-here)
- [Index over restatement still applies, with one carve-out](#index-over-restatement-still-applies-with-one-carve-out)
- [See also](#see-also)

How to **use** the services this fleet runs, as opposed to how they're
configured. Everything here is reachable over the tailnet and nowhere else.

This is a different tier from the rest of the wiki, and deliberately so. The
[category pages](../categories/README.md) answer *"how is this built, and
what breaks"* — they're for whoever is editing `flake/modules/`. These pages
answer *"I want to do a thing with the running service"* — no Nix involved,
and useful on a phone.

The split matters because the two rot differently. A category page goes stale
when the config changes; a page here goes stale when the *service* changes
under it, which can happen with no commit to this repo at all.

## Pages

| Service | Host | Reach it at | Page |
|---|---|---|---|
| *(all of cube's web services)* | `nire-cube` | `https://ts-cube.moose-micro.ts.net/` | [Reaching cube's services](reaching-services.md) |
| *(what's still unfinished)* | `nire-cube` | — | [Pending setup](pending-setup.md) |
| golink — `go/` shortlinks | `nire-cube` | `http://go/` | [Creating go/ links](creating-golinks.md) |
| Forgejo — self-hosted git forge | `nire-cube` | `.../git/` | [Using the forge](forgejo.md) |
| homepage — the landing page: services, status, weather, calendar | `nire-cube` | `https://homepage.moose-micro.ts.net/` (short: `http://homepage/`; also `.../` on cube's own name) | [Reaching cube's services](reaching-services.md); [landing](../categories/landing.md) covers config |
| restic — backups to the QNAP | `nire-cube` | — (no URL; a timer, not a listener) | [Backup runbook](backup-runbook.md) |

**Not a service of its own, but related**: [rustic](rustic.md) — a TUI that
can browse and restore from the same repository the row above writes.
Installed 2026-08-28 (`ellyHomeManager`-wide) and switched on cube as of
2026-08-30, but not yet run against a real repository — the QNAP mount
itself isn't working yet either (see the runbook).

**Start at that second one if you don't know what's running.** It lists the
services below, live-checks each one, and shows how cube itself is doing —
so it answers "what's on here and is it up" without reading this page.

## Also running, not yet written up

On `nire-cube`, reachable over the tailnet only, with a category page
covering configuration but no usage page here yet.

| Service | Reach it at | Configuration |
|---|---|---|
| Grafana — dashboards over cube's own metrics | `https://grafana.moose-micro.ts.net/` (short: `http://grafana/`) | [monitoring](../categories/monitoring.md) |

Grafana mostly doesn't need one: you log in and look at the dashboards
[monitoring](../categories/monitoring.md) provisions. What *would* be worth
writing up is adding a dashboard that survives a rebuild — anything edited in
the UI lives only in cube's sqlite db, while anything under the module's
`_dashboards/` is provisioned read-only from the store.

**Those URLs have changed twice.** The port forms
(`http://ts-cube:3000/`, `http://ts-cube:3001/`) stopped answering
2026-08-24, when both services moved to loopback behind Caddy; the path
forms (`https://ts-cube.moose-micro.ts.net/grafana/`, `/git/`) stopped
answering 2026-09-07, when each app got its own Tailscale Services hostname
and certificate. Caddy still terminates TLS for all of them, with certs
issued by `tailscaled` — see
[reverse-proxy](../categories/reverse-proxy.md).

The short names (`http://grafana/`, `http://git/`, `http://homepage/`) redirect
to the full ones. Use `http://`, not `https://`: the bare names cannot have a
publicly-trusted certificate, so the `https://` form shows a browser warning
by design. Full map and the reasoning:
[reaching-services](reaching-services.md).

`ts-cube`, **not** `nire-cube`: this tailnet's device names don't match
`networking.hostName`. That trip-up has its own writeup in
`system/networking/tailscale.nix`'s header, indexed from
[system](../categories/system.md).

golink is the exception to that pattern rather than a naming inconsistency —
it's its own tailnet device named `go`, not a port on cube, which is why its
URL looks nothing like the other two. See
[shortlinks](../categories/shortlinks.md).

## Half-finished is the normal state here

Several of these services are running, reachable, and still missing the
human step that makes them useful — Forgejo has no users, golink has no
links, and nothing is backed up. [Pending setup](pending-setup.md) is the
list, kept separate from [open-threads.md](../open-threads.md) because
those are the *repo's* loose ends and these are the *fleet's*: one-time
operational work that no commit will ever complete, because it lives in a
service's own database rather than in Nix.

## Index over restatement still applies, with one carve-out

[styleguide.md](../styleguide.md)'s rule holds here: link to the real source
rather than copying it. The carve-out is that for these pages the "real
source" is often **the running service's own help page**, not a file in this
repo — `http://go/.help` for golink, for instance. So a page here may hold
real synthesized content, the way a category deep-dive is allowed to, but it
should say what it verified against the live service and what it merely
transcribed. [creating-golinks.md](creating-golinks.md) ends with exactly that split.

## See also

- [hosts.md](../hosts.md) — which host runs what, and current switch status.
- [categories/README.md](../categories/README.md) — the configuration side.
