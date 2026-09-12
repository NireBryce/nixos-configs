# `landing`, for agents

_Last modified: 2026-09-12_

Condensed from [landing.md](landing.md), which keeps the reasoning and the
verification narrative. Facts only here.

Homepage (gethomepage), the landing page for `nire-cube` — replaced glance
2026-09-12 (issue #291); category `landing` itself dates to 2026-08-24,
nested under `homelab` 2026-08-27. One file, `nixos`-class:
`nire/homelab/landing/homepage/homepage.nix`, nixpkgs option family
`services.homepage-dashboard` (attrsets → `/etc/homepage-dashboard/*.yaml`).

Served at `https://ts-cube.moose-micro.ts.net/` (the root route) and at its
own `https://homepage.moose-micro.ts.net/` (short: `http://homepage/` —
pending the `svc:homepage` vip-put; see [Route](#route) below). Port
3002, loopback.

## Facts

- **Not a monitoring system.** `siteMonitor` sends an HTTP request and
  reports status/latency — no scraping, storing, alerting or retention.
  Prometheus ([monitoring](monitoring.md)) is still what knows the past.
- Named `homepage`, not `landing` (category/module name collision) and not
  `dashboard` (`monitoring` is full of Grafana dashboards; two things
  called "the dashboard one" costs a grep).
- **The loopback bind is an environment variable, not an option** —
  `systemd.services.homepage-dashboard.environment.HOSTNAME =
  "127.0.0.1"`. The nixpkgs module exposes only `listenPort`; next 16's
  `--hostname` flag has no env binding; the standalone `server.js`
  template the package runs is `process.env.HOSTNAME || '0.0.0.0'`
  (verified next 16.2.6 / homepage-dashboard 1.13.2). **The firewall is
  not the backstop**: `trustedInterfaces` lets tailnet traffic bypass the
  allow-list, so a widened bind is reachable tailnet-wide, skipping Caddy
  and TLS. A next bump can silently widen it — `ss -ltn | grep 3002`
  after every homepage-dashboard bump.
- `allowedHosts = "ts-cube.moose-micro.ts.net,homepage.moose-micro.ts.net"`
  — Homepage's middleware checks the Host header **exactly** (portless;
  localhost forms auto-allowed). A missing name is a middleware 403, not
  a Caddy error.
- Secrets: sops key **`homepage-env`** is a systemd EnvironmentFile; one
  `HOMEPAGE_VAR_ICAL_<NAME>=<secret-gcal-ics-url>` line per calendar.
  systemd parses it as root pre-DynamicUser-drop (default 0400 root is
  correct). At boot `sops-install-secrets` runs in `sysinit.target`,
  before any normal service — no ordering needed. `restartUnits` on the
  secret bounces homepage on change.
- Calendar integrations: names in `homepage.nix`'s `calendars` attrset;
  services.yaml carries literal `{{HOMEPAGE_VAR_ICAL_FAMILY}}` placeholders
  homepage substitutes at load. Fetched **server-side**; the proxy strips
  the URL from client responses. Fetch failure is **quiet** — bare grid +
  empty agenda, no error chip — so an unfilled secret looks like "no
  events", not breakage.
- Service cards derive from `services.caddy.virtualHosts` (throw-on-orphan,
  issue #221); golink hand-written (own tailnet device). Checks go through
  the proxy at person-URLs; homepage follows redirects explicitly
  (`follow-redirects`), so Grafana's 302→/login reads up.
- No `icon` fields on purpose — every icon form homepage knows resolves
  via `cdn.jsdelivr.net` (prefixes AND bare `.png`/`.svg`/`.webp`
  fallback); no icon set renders none.
- No firewall entry (loopback), no persistence entry (cube has a
  persistent root; StateDirectory/CacheDirectory hold nothing worth
  keeping).

## Traps

- **All-interfaces by default** — see the loopback bullet above; the one
  thing to re-check on a homepage-dashboard/next bump.
- **Until the sops value has real URLs the calendars show no events and
  no error** — that's by design (quiet ical failures), not a bug to
  chase.
- **`homepage.moose-micro.ts.net` not resolving** post-switch means the
  `svc:homepage` Service object was never vip-put (or the ACL
  approver/grant never applied) — the rollout commands are in
  `homepage.nix`'s history section; `just tailscale-acl diff` catches
  drift. Not a Caddy problem.
- **Only list services a browser on another host can reach.** A card's
  title is its link; loopback-only services belong in Grafana, not here.
- **A 200 from `/` proves the page loads, not that widgets render** —
  homepage is client-side; after switching, check the rendered page and
  the siteMonitor latencies on the cards.

## Route

`https://ts-cube.moose-micro.ts.net/` (root) + `https://homepage.moose-micro.ts.net/`
(svc:homepage, the #211/#220 pattern) + `http://homepage/` short door.
Binds `127.0.0.1:3002`; Caddy terminates TLS for both names.

## Imported by

`nire-cube` only (via the `homelab` umbrella). **Paired with
[reverse-proxy](reverse-proxy.md)**: Caddy's root route proxies to
`127.0.0.1:3002`, so dropping `landing` while keeping `reverse-proxy`
leaves the front page at 502.

## See also

[landing.md](landing.md) · [reverse-proxy.md](reverse-proxy.md) ·
[monitoring.md](monitoring.md) · [shortlinks.md](shortlinks.md)
