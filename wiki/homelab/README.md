# Homelab services

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
| golink — `go/` shortlinks | `nire-cube` | `http://go/` | [Creating go/ links](golinks.md) |
| glance — the service index | `nire-cube` | `https://ts-cube.moose-micro.ts.net/` | not yet written up; [landing](../categories/landing.md) covers config |

**Start at that second one if you don't know what's running.** It lists the
services below, live-checks each one, and shows how cube itself is doing —
so it answers "what's on here and is it up" without reading this page.

## Also running, not yet written up

Both are on `nire-cube` and reachable over the tailnet only. They have
category pages covering configuration; neither has a usage page here yet.

| Service | Reach it at | Configuration |
|---|---|---|
| Grafana — dashboards over cube's own metrics | `https://ts-cube.moose-micro.ts.net/grafana/` | [monitoring](../categories/monitoring.md) |
| Forgejo — self-hosted git forge | `https://ts-cube.moose-micro.ts.net/git/` | [git-forge](../categories/git-forge.md) |

**Those URLs changed on 2026-08-24**, and the old ones
(`http://ts-cube:3000/`, `http://ts-cube:3001/`) no longer answer at all.
Both services moved to loopback and are now reached through Caddy, which
holds a real TLS certificate issued by tailscaled — see
[reverse-proxy](../categories/reverse-proxy.md). `http://ts-cube/`
redirects to the Grafana/Forgejo index, so the short name is still a usable
starting point.

`ts-cube`, **not** `nire-cube`: this tailnet's device names don't match
`networking.hostName`. That trip-up has its own writeup in
`system/networking/tailscale.nix`'s header, indexed from
[system](../categories/system.md).

golink is the exception to that pattern rather than a naming inconsistency —
it's its own tailnet device named `go`, not a port on cube, which is why its
URL looks nothing like the other two. See
[shortlinks](../categories/shortlinks.md).

## Index over restatement still applies, with one carve-out

[styleguide.md](../styleguide.md)'s rule holds here: link to the real source
rather than copying it. The carve-out is that for these pages the "real
source" is often **the running service's own help page**, not a file in this
repo — `http://go/.help` for golink, for instance. So a page here may hold
real synthesized content, the way a category deep-dive is allowed to, but it
should say what it verified against the live service and what it merely
transcribed. [golinks.md](golinks.md) ends with exactly that split.

## See also

- [hosts.md](../hosts.md) — which host runs what, and current switch status.
- [categories/README.md](../categories/README.md) — the configuration side.
