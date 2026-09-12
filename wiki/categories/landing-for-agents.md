# `landing`, for agents

_Last modified: 2026-09-11_
_Sibling reviewed: 2026-09-12 -- landing.md's change was only retargeting a link (the `/git` 404 anchor moved from reverse-proxy.md to reverse-proxy-history.md); this page doesn't cite that anchor and needs no change._

Condensed from [landing.md](landing.md), which keeps the reasoning and the
verification narrative. Facts only here.

glance, the service index for `nire-cube`. Added 2026-08-24, nested under
`homelab` 2026-08-27. One file, `nixos`-class:
`nire/homelab/landing/glance/glance.nix`.

Served at `https://ts-cube.moose-micro.ts.net/` (the root route) and, since
2026-09-11, at its own `https://glance.moose-micro.ts.net/` (short:
`http://glance/`). Binds `127.0.0.1:3002`.

## Facts

- **Not a monitoring system.** The `monitor` widget sends a GET and reports
  the status code — no scraping, storing, alerting or retention. Prometheus
  ([monitoring](monitoring.md)) is still what knows the past.
- Named `landing`, not `glance` (category/module name collision) and not
  `dashboard` (two categories reasonably called "the dashboard one" costs a
  grep later).
- `proxied = true` is load-bearing: it tells glance to trust Caddy's
  `X-Forwarded-*` headers, so it sees the real client instead of
  `127.0.0.1`.
- `base-url` stays unset because glance is the fallback `handle` at the root
  of the vhost. **If it ever moves under a prefix, `base-url` must be set
  AND the proxy must strip** — Forgejo's shape, not Grafana's.
- No firewall entry (loopback), no persistence entry (cube has a persistent
  root, and nothing in `/var/lib/glance` is worth keeping anyway).

## Traps

- **A 200 from the page proves almost nothing.** Widget content renders
  behind `/api/pages/home/content/`, not in the initial HTML. That endpoint
  is the actual confirmation.
- **Grafana's row depends on redirect-following.** `/grafana/` answers 302,
  and only 200 counts as OK. It works because `defaultHTTPClient` sets no
  `CheckRedirect` so Go follows up to 10. If that changes, the fix is
  `alt-status-codes: [302]`, not a Grafana change.
- **No icons, deliberately** — the `si:`/`sh:`/`di:`/`mdi:` prefixes load
  from `cdn.jsdelivr.net`, which would quietly send tailnet-only traffic
  off-tailnet on every page load. `assets-path` is the local alternative.
- **Only list services a browser on another host can reach.** The monitor
  widget's title *is* the link, so a loopback-only service renders as a
  broken link — correct as a health check, misleading as UI.
- Monitored sites are checked **through the proxy**, at the URLs a person
  would use, not at `127.0.0.1:300x` — that makes the widget test MagicDNS,
  the tailnet, Caddy routing, the certificate and the app together.

## Imported by

`nire-cube` only. **Paired with [reverse-proxy](reverse-proxy.md)**: Caddy's
root route proxies to `127.0.0.1:3002`, so dropping `landing` while keeping
`reverse-proxy` leaves the front page at 502.

## See also

[landing.md](landing.md) · [reverse-proxy.md](reverse-proxy.md) ·
[monitoring.md](monitoring.md) · [shortlinks.md](shortlinks.md)
