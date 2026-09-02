# `landing` — `nire/homelab/landing/`

## Contents

- [What's in it](#whats-in-it)
- [What it is not](#what-it-is-not)
- [Why the category isn't `dashboard` (or `glance`)](#why-the-category-isnt-dashboard-or-glance)
- [The one route with no prefix problem](#the-one-route-with-no-prefix-problem)
- [Two things that could have gone quietly wrong, and didn't](#two-things-that-could-have-gone-quietly-wrong-and-didnt)
- [No icons, deliberately](#no-icons-deliberately)
- [Only clickable services are listed](#only-clickable-services-are-listed)
- [No firewall entry, no persistence entry](#no-firewall-entry-no-persistence-entry)
- [Imported by](#imported-by)
- [See also](#see-also)

[glance](https://github.com/glanceapp/glance), the service index for
`nire-cube`: what's running, whether it's up, and how the machine itself is
doing. Added 2026-08-24, cube-only; nested under the `homelab` umbrella
since 2026-08-27 (name unaffected). It is what
`https://ts-cube.moose-micro.ts.net/` serves.

**Confirmed working end to end, 2026-08-24**, first switch, no fixes:
`glance.service` `active (running)` at `NRestarts=0`, 0 failed units, 3002
bound to `127.0.0.1` only, root URL 200 over validated TLS from another
tailnet host.

A 200 from the page proves less than it looks like: glance renders widget
content behind `/api/pages/home/content/`, not in the initial HTML. That
endpoint reported all three monitored sites **OK** with the server-stats
widget rendering CPU/SWAP for `nire-cube` — which is the actual
confirmation.

## What's in it

One file, `nixos`-class: `glance/glance.nix`.

## What it is not

A second monitoring system. The `monitor` widget sends a GET and reports the
status code; it does not scrape, store, alert, or retain anything.
[monitoring](monitoring.md)'s Prometheus is still what knows what CPU usage
was an hour ago. This answers *"is it up right now, and what's the URL"* —
the question [homelab/README.md](../homelab/README.md) answers for humans,
which nothing on the machine itself answered before.

## Why the category isn't `dashboard` (or `glance`)

Not `glance`, for the collision reason [git-forge](git-forge.md) isn't
`forgejo`: a category and its one module sharing a name declare the same
`flake.modules.nixos.<name>` attribute and silently **merge**.

Not `dashboard` either, which is the more interesting half.
[monitoring](monitoring.md) next door is full of Grafana dashboards, and two
categories both reasonably described as "the dashboard one" is exactly the
ambiguity that costs a grep later. `landing` is the page you land on; Grafana
is where you go to read graphs.

## The one route with no prefix problem

[reverse-proxy](reverse-proxy.md) mounts Grafana at `/grafana` and Forgejo at
`/git`, and those two need **opposite** prefix handling — the mistake that
cost a switch. glance is the fallback `handle` at the root of the same vhost,
so nothing is stripped and nothing is preserved, and `base-url` stays unset.
Its own assets under `/static/` fall through the same route, which is right:
they aren't under a prefix either.

If it ever *does* move under a prefix, glance's docs are explicit that
`base-url` must be set **and** the proxy must strip — Forgejo's shape, not
Grafana's.

`proxied = true` is set, which is not cosmetic: it tells glance to trust the
`X-Forwarded-*` headers Caddy sets, so it sees the real client rather than
`127.0.0.1` for every request.

## Two things that could have gone quietly wrong, and didn't

Both were reasoned out of glance's source before the switch and are now
confirmed live. Both would have rendered as plausible-looking wrong output
rather than an error:

- **Grafana's row depends on redirect-following.** `/grafana/` answers 302 →
  `/grafana/login`, and `statusCodeToText` treats only 200 (or an explicit
  `alt-status-codes` entry) as OK. It reads OK because
  `defaultHTTPClient` (`widget-utils.go`) sets no `CheckRedirect`, so Go's
  default follow-up-to-10 policy applies. If that ever changes, the fix is
  `alt-status-codes: [302]`, not a change to Grafana.
- **golink answers requests originating from cube.** `http://go/` is a
  separate tailnet device ([shortlinks](shortlinks.md) embeds tsnet), so this
  depended on MagicDNS resolving `go` *from cube* and on golink serving its
  index to that node without interactive auth. It does.

## No icons, deliberately

The monitor and bookmarks widgets accept `si:`/`sh:`/`di:`/`mdi:` icon
prefixes — and glance's own documentation says those "are loaded externally
and are hosted on `cdn.jsdelivr.net`". This is a page reachable only from the
tailnet whose whole point is that it doesn't leave the tailnet; fetching an
icon per service from a CDN on every load would quietly undo that, for no
gain over three legible titles. `assets-path` serves a local directory under
`/assets/` if icons are ever wanted without the CDN.

## Only clickable services are listed

The monitor widget's title **is** the link, so a loopback-only service
(Prometheus on `127.0.0.1:9090`, node-exporter, cadvisor, libvirt-exporter)
would render as a link that fails in the reader's browser — correct as a
health check, actively misleading as a UI. Their health surfaces in Grafana,
which is listed. Don't add them here without also giving them a URL a browser
on another host can follow.

The three sites are checked **through the proxy**, at the same URLs a person
would use, rather than at `127.0.0.1:300x`. That makes the widget a test of
the whole path — MagicDNS, the tailnet, Caddy's routing, the certificate, and
the app — instead of the app alone. A Caddy misconfiguration shows up here;
a loopback check would have hidden exactly the class of bug that actually
happened ([the `/git` 404](reverse-proxy.md#the-two-apps-want-opposite-things-from-the-proxy)).

## No firewall entry, no persistence entry

Loopback binding means nothing arrives at the firewall for it, so there is
nothing to allow — same as every other service behind
[reverse-proxy](reverse-proxy.md). And `nire-cube` has a plain persistent
root (`cube-configuration.nix`'s header), so `/var/lib/glance` survives
reboots with no `environment.persistence` entry. Worth noting there is
nothing in there worth keeping anyway: every widget is derived from live
state, and the config comes from the store.

## Imported by

`nire-cube` only, as of 2026-08-24. This import and
[reverse-proxy](reverse-proxy.md)'s are a **pair** — Caddy's root route
proxies to `127.0.0.1:3002`, so dropping `landing` while keeping
`reverse-proxy` leaves the site's front page returning 502.

## See also

- [reverse-proxy](reverse-proxy.md) — what serves this at `/`, and the
  prefix-handling asymmetry this module sidesteps by living at the root.
- [monitoring](monitoring.md) — the actual metrics stack, which this is
  deliberately not a replacement for.
- [shortlinks](shortlinks.md) — golink, one of the three monitored services
  and the only one that isn't on this host.
- [homelab/README.md](../homelab/README.md) — the human-facing version of the
  same index.
- [hosts.md](../hosts.md) — current switch/verification status for
  `nire-cube`.
