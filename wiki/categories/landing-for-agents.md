# `landing`, for agents

_Last modified: 2026-10-06_

Condensed from [landing.md](landing.md). Homepage (gethomepage) is nire-cube's
landing page (replaced glance 2026-09-12, #291). Category dates 2026-08-24, nested under `homelab` 2026-08-27.

## Modules

- `general-config/homelab/landing/homepage/homepage.nix` (`nixos`): `services.homepage-dashboard`
  (attrsets → `/etc/homepage-dashboard/*.yaml`). Port **3002**, loopback. Served at
  `https://ts-cube.moose-micro.ts.net/` (root route) and `https://homepage.moose-micro.ts.net/` (short `http://homepage/`).
- `glance/glance.nix` (glance 0.8.5, port **3004**, loopback), rejoined 2026-09-13 for the landing
  evaluation: only at `glance.moose-micro.ts.net` (`http://glance/`). End of evaluation = delete
  the loser's module + caddy vhosts + serve.nix endpoints + `svc-*.json` + ACL entries.
- Runtime-verified 2026-09-12 from tenacity: 200/validated TLS on all doors, unit clean, 3002
  loopback-only; real browser: widgets, cards draw. **Calendars removed 2026-10-06** (#299, removed-not-filled:
  the 09-29 sops fill still 403'd and the placeholder kept hitting Google) — no `calendars` attrset, no
  calendar service widgets, no `homepage-env` sops declaration (key remains in secrets.yaml, unreferenced).
  Re-add per [landing.md](landing.md)'s gcal section.

## Facts

- **Not a monitoring system**: `siteMonitor` = HTTP request, status/latency only; no storage or alerting. Prometheus ([monitoring](monitoring.md)) keeps history.
- Named `homepage`, not `landing` (category/module collision) nor `dashboard` (Grafana).
- **Loopback bind is an env var, not an option**: `systemd.services.homepage-dashboard.environment.HOSTNAME = "127.0.0.1"`.
  nixpkgs exposes only `listenPort`; standalone `server.js` is `process.env.HOSTNAME || '0.0.0.0'`
  (verified next 16.2.6 / homepage-dashboard 1.13.2). **Firewall is no backstop**: `trustedInterfaces`
  lets tailnet traffic bypass it, so a widened bind is tailnet-wide, skipping Caddy/TLS.
  Run `ss -ltn | grep 3002` after every homepage-dashboard bump.
- `allowedHosts = "ts-cube.moose-micro.ts.net,homepage.moose-micro.ts.net"`: Host header checked
  **exactly** (localhost forms auto-allowed). Missing name = middleware 403, not a Caddy error.
- Calendars until 2026-10-06 (#299): sops key `homepage-env` = EnvironmentFile, one
  `HOMEPAGE_VAR_ICAL_<NAME>=<secret-gcal-ics-url>` per calendar (systemd read it as root pre-DynamicUser;
  `restartUnits` bounced homepage on change); names in the `calendars` attrset, `{{HOMEPAGE_VAR_ICAL_FAMILY}}`
  placeholders in services.yaml, fetched server-side with the URL stripped from client responses.
  All of that is GONE from the live config; the recipe and the systemd/sops mechanics live in
  [landing.md](landing.md)'s gcal section for a future re-add.
- **`calendar` is a SERVICE widget, not info widget** (still true, matters on re-add):
  `widget = { type = "calendar"; view = ...; }` under a service entry, one per view. A `calendar` line in
  widgets.yaml renders "Missing calendar", no error.
- Service cards derive from `services.caddy.virtualHosts` (throw-on-orphan, #221); golink hand-written
  (own tailnet device). Checks go via the proxy at person-URLs with `follow-redirects` (Grafana 302→/login reads up).
- No `icon` fields on purpose: every icon form resolves via `cdn.jsdelivr.net`; no icon set renders none.
- No firewall entry (loopback), no persistence entry (persistent root).

## Traps

- **Calendar views are gone** (since 2026-10-06, #299): no calendar cards on the page. Don't
  chase a "regression" — they were removed; see Modules.
- **git/grafana status badges reading failure** ([#298](https://github.com/NireBryce/nixos-configs/issues/298)),
  fixed 2026-09-14: cube's tailscaled served no `svc:` MagicDNS records (hard-IP curl worked; name layer only).
  Tagged device is owned by its tag; every `svc:` grant sourced `autogroup:members`, so cube (only tagged
  host, only `svc:` advertiser) had no grant to its own destinations. Fix: one grant for `tag:homelab-cube`.
- **`homepage.moose-micro.ts.net` not resolving** post-switch = `svc:homepage` never vip-put or ACL
  approver/grant not applied; rollout commands in `homepage.nix`'s history section;
  `just tailscale-acl diff` catches drift. Not Caddy.
- **List only services a browser on another host can reach** (card title is its link); loopback-only belongs in Grafana.
- **200 from `/` proves nothing about widgets** (client-side): check rendered page and card siteMonitor latencies.

## Route

Root + `svc:homepage` (#211/#220 pattern) + `http://homepage/`. Binds `127.0.0.1:3002`; Caddy terminates TLS for both names.

## Imported by

`nire-cube` only (via the `homelab` umbrella). **Paired with
[reverse-proxy](reverse-proxy.md)**: Caddy's root route proxies to
`127.0.0.1:3002`, so dropping `landing` while keeping `reverse-proxy`
leaves the front page at 502.

## See also

[landing.md](landing.md) · [reverse-proxy.md](reverse-proxy.md) ·
[monitoring.md](monitoring.md) · [shortlinks.md](shortlinks.md)
