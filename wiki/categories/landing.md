# `landing` — `nire/homelab/landing/`

_Last modified: 2026-09-12_

[Homepage (gethomepage)](https://gethomepage.dev), the landing page for
`nire-cube`: what's running, whether it's up, how the machine itself is
doing, and the household calendar. The category has existed since
2026-08-24, cube-only, nested under the `homelab` umbrella since
2026-08-27 (name unaffected) — but the app underneath it changed
2026-09-12: **homepage replaced glance** (issue #291), because homepage's
calendar widget natively renders events from iCal feeds in a month grid
*and* an agenda view, which glance could not be configured to do at all
and which #208/#289/#290 existed to patch it into.

**Runtime status: config landed 2026-09-12, switch pending.** The build
against cube is green and the generated files are verified (unit
environment, YAML, Caddyfile all read back); the live-service checks fill
in after `just switch`. Until then the running page is still glance.

> **Condensed version:**
> [landing-for-agents.md](landing-for-agents.md) — the same
> ground with the narrative stripped out, for an agent (or a human in
> a hurry) loading it mid-task. Both siblings get edited in the same
> change.

## Contents

- [What's in it](#whats-in-it)
- [What it is not](#what-it-is-not)
- [Why the module isn't `dashboard` (or `landing`)](#why-the-module-isnt-dashboard-or-landing)
- [The widgets](#the-widgets)
- [How the gcal calendar feeds work](#how-the-gcal-calendar-feeds-work)
- [Loopback bind is not free here](#loopback-bind-is-not-free-here)
- [Route and names](#route-and-names)
- [No icons, deliberately — twice over](#no-icons-deliberately--twice-over)
- [Only clickable services are listed](#only-clickable-services-are-listed)
- [No firewall entry, no persistence entry](#no-firewall-entry-no-persistence-entry)
- [Imported by](#imported-by)
- [glance, retired 2026-09-12](#glance-retired-2026-09-12)
- [See also](#see-also)

## What's in it

One file, `nixos`-class: `homepage/homepage.nix`. The nixpkgs module is
`services.homepage-dashboard` — structured Nix attrsets rendered to
`/etc/homepage-dashboard/*.yaml` (`services`, `widgets`, `settings`); no
database, config-in-git, same philosophy glance had.

## What it is not

A second monitoring system. A service card's `siteMonitor` is one HTTP
request reporting status and latency; it does not scrape, store, alert,
or retain anything. [monitoring](monitoring.md)'s Prometheus is still what
knows what CPU usage was an hour ago. This answers *"is it up right now,
and what's the URL"* — the question
[homelab/README.md](../homelab/README.md) answers for humans.

## Why the module isn't `dashboard` (or `landing`)

Not `landing`: the category and its module sharing a name declare the same
`flake.modules.nixos.<name>` attribute and silently **merge** (the
[git-forge](git-forge.md) isn't `forgejo` reason).

Not `dashboard` either, which is the more interesting half.
[monitoring](monitoring.md) next door is full of Grafana dashboards, and two
categories both reasonably described as "the dashboard one" is exactly the
ambiguity that costs a grep later. `landing` is the page you land on; Grafana
is where you go to read graphs.

## The widgets

| homepage widget | shows | replaces (glance) |
|---|---|---|
| service cards + `siteMonitor` | Grafana, Forgejo, golink — status and latency, checked **through the proxy** at the URLs a person uses | `monitor` rows (same derivation from `services.caddy.virtualHosts`, throw-on-orphan, issue #221) |
| `resources` | cube's CPU / memory / disk / uptime | `server-stats` |
| `openmeteo` | New York weather, imperial, keyless (same api.open-meteo.com source) | `weather` (#226) |
| `calendar` (`view: monthly`) | month grid **with events** | `calendar` (#207 — bare grid, no events possible) |
| `calendar` (`view: agenda`) | upcoming events, time-sorted | *(nothing — #290's ask, met natively)* |

The service-card list is **derived** from caddy's vhost table — a vhost
renamed there flows into these URLs, and a vhost removed forces an edit here
(the derivation throws at eval). golink is the one hand-written card: it is
not this host's vhost at all (own tailnet device,
[shortlinks](shortlinks.md)).

## How the gcal calendar feeds work

The calendar sources are the household's Google Calendars via each
calendar's **secret iCal address** — no API key, no public-calendar
compromise (the source decision recorded in #208/#289/#290). The plumbing:

- The addresses live in exactly one place: the sops key **`homepage-env`**,
  whose value is a systemd `EnvironmentFile` — one
  `HOMEPAGE_VAR_ICAL_<NAME>=<secret-url>` line per calendar. Never in a Nix
  file, never in the store, never in the repo.
- `homepage.nix` declares the calendar *names* (the `calendars` attrset) and
  emits services.yaml entries whose `url` is the literal placeholder
  `{{HOMEPAGE_VAR_ICAL_FAMILY}}`; homepage substitutes from its environment
  at load (verified against v1.13.2's `utils/config/config.js`).
- **Everything fetches server-side**: the calendar proxy runs on cube, and
  it strips the URL from anything sent to the browser — the page can be
  viewed by anything on the tailnet without the secret addresses leaving
  the host.
- Until real URLs are filled in, an integration fetch fails **quiet** (no
  error chip): the calendar renders as a bare grid plus an empty agenda.
  Filling in the sops value and bouncing homepage (the secret's
  `restartUnits` does it at the next switch) turns events on with no
  further commit.
- **Adding a calendar is one line in each place**: an entry in
  `homepage.nix`'s `calendars`, a line in the sops value. Calendar IDs were
  deliberately not assigned at implementation — that's the one human step
  left, tracked in [homelab/pending-setup.md](../homelab/pending-setup.md).

## Loopback bind is not free here

glance had a `host` option and the security model was one setting. Homepage
binds **all interfaces** unless told otherwise, and neither the nixpkgs
module nor next's CLI exposes a bind host (checked: `services.homepage-dashboard`
has `listenPort` only; next 16's `--hostname` flag has no env binding). What
makes it work: the package runs next's *standalone* `server.js`, whose bind
line is `process.env.HOSTNAME || '0.0.0.0'` (read from next 16.2.6, the
version bundled with homepage-dashboard 1.13.2) — so the module sets
`HOSTNAME=127.0.0.1` in the unit environment.

The trap that makes this load-bearing: the firewall is **not** the backstop
it looks like. `trustedInterfaces` lets tailnet traffic bypass the
allow-list, so an all-interfaces 3002 would be directly reachable from the
tailnet, skipping Caddy and its TLS — exactly the shape grafana and forgejo
were moved off in 2026-08-24. And the failure mode of a future next version
changing that template line is a **silent widening** — no error anywhere —
so `ss -ltn | grep 3002` belongs in the checklist whenever homepage-dashboard
is bumped.

## Route and names

- `https://ts-cube.moose-micro.ts.net/` — the vhost root, the route with no
  prefix question; the page serves at `/`, nothing stripped.
- `https://homepage.moose-micro.ts.net/` — homepage's own Tailscale Service
  name (`svc:homepage`), the #211/#220 pattern its neighbours use.
- `http://homepage/` — the short door (redirects to the full name; type it
  with `http://`, see [reaching-services](../homelab/reaching-services.md)).

`svc:homepage` is the one piece **outside this repo**: the Service object
and its ACL approver/grant must be applied at switch time (the commands are
in `homepage.nix`'s history section). Until then the own-name does not
resolve — a missing Service object, not a broken Caddy. The
[reverse-proxy](reverse-proxy.md) pairing is unchanged: Caddy terminates TLS
for all three names, homepage sits on loopback behind it. A missing name in
`allowedHosts` (Homepage's Host-header check) is a middleware 403, not a
Caddy error — the failure shape if a future route move forgets the line.

## No icons, deliberately — twice over

glance's rule carried over and got stronger: **every** icon form homepage
understands resolves via `cdn.jsdelivr.net` (the `mdi:`/`si:`/`sh:`
prefixes *and* the bare `name.png`/`.svg`/`.webp` fallback — read from
v1.13.2's `resolvedicon.jsx`), while a service with no `icon` set renders
none at all. So none are set. A page whose point is not leaving the
tailnet must not pull icons from a CDN on every load.

## Only clickable services are listed

Same rule glance had: a loopback-only service (Prometheus, node-exporter,
cadvisor, libvirt-exporter) would render as a card that 404s in the
reader's browser — correct as a health check, actively misleading as a UI.
Their health surfaces in Grafana, which is listed. The `siteMonitor`
checks go **through the proxy**, at the URLs a person uses, not at
`127.0.0.1:300x` — that makes a card's status test MagicDNS, the tailnet,
Caddy's routing, the certificate and the app together. Homepage follows
redirects explicitly (`follow-redirects`), so Grafana's 302 → `/login`
reads as up, same as glance's monitor did.

## No firewall entry, no persistence entry

Loopback binding means nothing arrives at the firewall, so there is nothing
to allow — same as every service behind [reverse-proxy](reverse-proxy.md).
And `nire-cube` has a plain persistent root (`cube-configuration.nix`'s
header), so the module's StateDirectory/CacheDirectory survive reboots with
no `environment.persistence` entry. There is nothing worth keeping in them
anyway: every widget derives from live state, and the config comes from the
store.

## Imported by

`nire-cube` only (via the `homelab` umbrella). This import and
[reverse-proxy](reverse-proxy.md)'s are a **pair** — Caddy's root route
proxies to `127.0.0.1:3002`, so dropping `landing` while keeping
`reverse-proxy` leaves the site's front page returning 502.

## glance, retired 2026-09-12

[glance](https://github.com/glanceapp/glance) (v0.8.5) was the landing page
from 2026-08-24 until homepage replaced it (issue #291). Its module,
`glance/glance.nix`, is deleted — `git log --follow` has the full file.

What homepage inherited: the `landing` category and its naming reasoning,
port 3002, the loopback/no-firewall/no-persist shape, the derive-from-caddy-
vhosts mechanism (#221), the no-CDN rule, "only clickable services listed",
through-the-proxy health checks.

What retired with it:

- **The four to-do lists** (#209) — dropped, not replaced (#291's decision
  2). Homepage has no to-do widget; the lists lived in each *browser's*
  localStorage (per-device, not shared, lost on storage clear), and #209's
  "categories" were distinguishable only by position. Anyone who kept real
  tasks there will find them gone with the glance data.
- **glance's own traps**: the monitor row that depended on Go's default
  redirect-following (`alt-status-codes` was the fix if it ever changed),
  and the `/api/pages/<page>/content/` endpoint as the way to verify widget
  content behind a 200 (homepage is client-side; what to check instead is
  the rendered page plus `siteMonitor`'s reported latency, after the
  switch).
- The names `glance.moose-micro.ts.net` and `http://glance/`, and the
  `svc:glance` Service object — see [reaching-services](../homelab/reaching-services.md)'s
  muscle-memory table and [reverse-proxy](reverse-proxy.md) for the
  control-plane half.

## See also

- [reverse-proxy](reverse-proxy.md) — what serves this at `/`, the
  certificate mechanism, and the Tailscale Services split.
- [monitoring](monitoring.md) — the actual metrics stack, which this is
  deliberately not a replacement for.
- [shortlinks](shortlinks.md) — golink, one of the listed services and the
  only one that isn't on this host.
- [homelab/README.md](../homelab/README.md) — the human-facing version of
  the same index.
- [hosts.md](../hosts.md) — current switch/verification status for
  `nire-cube`.
