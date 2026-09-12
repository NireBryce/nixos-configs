# Reaching cube's services

_Last modified: 2026-09-12_

Each web service on `nire-cube` has **its own tailnet hostname and its own
certificate**. That is a change from the original design — one hostname with
path prefixes — which this page described until 2026-09-11 and which is now
retired. For how it's built, see
[reverse-proxy](../categories/reverse-proxy.md).

> **Condensed version:**
> [reaching-services-for-agents.md](reaching-services-for-agents.md) — the same
> ground with the narrative stripped out, for an agent (or a human in
> a hurry) loading it mid-task. Both siblings get edited in the same
> change.

## Contents

- [The map](#the-map)
- [Muscle memory: what stopped answering, and when](#muscle-memory-what-stopped-answering-and-when)
- [Why it's HTTPS, and the one warning you will still see](#why-its-https-and-the-one-warning-you-will-still-see)
- [When something doesn't answer](#when-something-doesnt-answer)
- [Adding another service to this](#adding-another-service-to-this)
- [What's verified here](#whats-verified-here)
- [See also](#see-also)

## The map

| What | URL | Short form |
|---|---|---|
| Landing page (homepage) | `https://homepage.moose-micro.ts.net/` | `http://homepage/` |
| Grafana | `https://grafana.moose-micro.ts.net/` | `http://grafana/` |
| Forgejo | `https://git.moose-micro.ts.net/` | `http://git/` |
| cube itself (also the landing page) | `https://ts-cube.moose-micro.ts.net/` | `http://ts-cube/` |
| golink (**not** on cube) | `http://go/` — see [creating go/ links](creating-golinks.md) | |

**Type the short form with `http://`, not `https://`.** Both work, but they
behave differently and only one is pleasant — see
[the warning section](#why-its-https-and-the-one-warning-you-will-still-see).

**Start at the landing page.** It lists the services, live-checks each one,
shows cube's CPU/memory/disk and the household calendar — so "what's running
and is it up" is answered by looking, not by reading this page. It answers on
both its own name and cube's. (Homepage since 2026-09-12, issue #291; the
`homepage...` short name needs the `svc:homepage` Service object applied at
switch time — until then use cube's own name, which needs nothing new.)

`ts-cube`, **not** `nire-cube`: this tailnet renames its devices. That trap
has its own writeup in `system/networking/tailscale.nix`, indexed from
[system](../categories/system.md).

## Muscle memory: what stopped answering, and when

| Old | New | Retired |
|---|---|---|
| `http://ts-cube:3000/` | `https://grafana.moose-micro.ts.net/` | 2026-08-24 |
| `http://ts-cube:3001/` | `https://git.moose-micro.ts.net/` | 2026-08-24 |
| `https://ts-cube.moose-micro.ts.net/grafana/` | `https://grafana.moose-micro.ts.net/` | 2026-09-07 |
| `https://ts-cube.moose-micro.ts.net/git/` | `https://git.moose-micro.ts.net/` | 2026-09-07 |
| `https://glance.moose-micro.ts.net/`, `http://glance/` | `https://homepage.moose-micro.ts.net/` (or cube's own root, unchanged) | 2026-09-12 |

The port URLs went away because both apps moved to loopback — reachable only
through Caddy, so a firewall mistake no longer exposes them. The path
prefixes went away because Tailscale Services gave each app a real hostname
of its own, which is both nicer to type and removes a whole class of
prefix-rewriting bugs (see
[reverse-proxy-history](../categories/reverse-proxy-history.md)).

## Why it's HTTPS, and the one warning you will still see

For the **full names** — `git.moose-micro.ts.net` and friends — the
certificate is issued by **Tailscale**, fetched by Caddy from the local
`tailscaled`. No ACME account, no self-signed warning, nothing to install on
your devices: `*.ts.net` names get real, publicly-trusted certs.

For the **short names** — bare `git`, `grafana`, `glance` — it depends
entirely on the scheme, and this catches people:

- **`http://git`** redirects to the full name. No certificate is involved in
  the redirect at all, so you land on the real trusted cert with no warning
  anywhere. **This is the one to use.**
- **`https://git`** shows a browser warning (`SEC_ERROR_UNKNOWN_ISSUER`).
  That is not a bug and cannot be fixed: `git` is not a `.ts.net` name, so
  neither Tailscale nor any public CA will ever issue for it, and Caddy
  answers with its own local CA instead. It exists only so that a browser
  that forces HTTPS gets a click-through warning rather than a hard,
  unexplainable failure.

Two things follow that are worth knowing as a user:

- **It only works on the tailnet.** These names don't resolve elsewhere and
  nothing is exposed to the internet. This is not Funnel.
- **Prefer the full name in bookmarks.** The short names are for typing.

## When something doesn't answer

Work down this list; it's ordered by what's most often actually wrong.

1. **Is your device on the tailnet?** `tailscale status` on the machine
   you're browsing from. Everything here is tailnet-only.
2. **Does another service answer?** These are now independent names on
   independent virtual addresses, so "Grafana is down" and "cube is down"
   are genuinely different questions. If `https://ts-cube.moose-micro.ts.net/`
   answers but `https://git.moose-micro.ts.net/` doesn't, cube and Caddy are
   fine — suspect that one Service or that one app.
3. **Does the name resolve at all?** `getent hosts git.moose-micro.ts.net`.
   A Service name that doesn't resolve means the `svc:` object is missing or
   unapproved, not that the app is down — a distinct failure with its own
   fix, see [reverse-proxy](../categories/reverse-proxy.md).
4. **Does the port answer?** A Service VIP only listens on the ports its
   Service object *and* `serve.nix` both declare. A connection that times out
   while another port on the same name works means a missing endpoint, not a
   dead app.
5. **Is cube up?** `ping ts-cube`. A `tailscale ping` that works while HTTP
   doesn't can also mean a tailnet grant is blocking traffic — fixed in the
   policy file (`just tailscale-acl`), not in the app.
6. **Ask the host**, over ssh:
   ```sh
   systemctl status caddy grafana forgejo homepage-dashboard tailscale-serve
   systemctl list-units --state=failed
   ```
   `NRestarts` is the number to look at, not just `active` — a service that
   crashes and restarts in a loop reports `active` between restarts. Include
   `tailscale-serve`: when it fails, every `svc:` name goes dark at once
   while cube's own name keeps working.
7. **Check the journal for the one that's failing**, `journalctl -u <unit> -n
   50`. Certificate problems show up in `caddy`'s journal — but note its log
   level is `ERROR` by default, which hides the warning Caddy emits when
   `tailscaled` declines to give it a certificate.

**A TLS error is not a dead service.** `SSL_ERROR_INTERNAL_ERROR_ALERT` on a
`.ts.net` name means Caddy has no certificate to offer and is usually a
config bug, not an outage — that exact failure took down all four names for
two days in September 2026. See
[reverse-proxy](../categories/reverse-proxy.md).

## Adding another service to this

Short version: it binds loopback, gets its own `svc:` name, and needs three
things to agree — the Service object, `serve.nix`'s endpoints (**both**
`tcp:443` and `tcp:80`), and a Caddy vhost. The long version is the
`new-tailscale-service` skill; `new-homelab-service` covers writing the
service module itself first.

## What's verified here

Exercised against the live instance on **2026-09-11** from `nire-tenacity`,
over the tailnet:

- All four full names return `HTTP 200`/`302` with `ssl_verify_result 0` —
  the certificate validated against the system trust store, not merely
  presented.
- All four short `http://` names return `301` to their full name, and
  following the redirect lands on `200` with `ssl_verify_result 0`.
- glance answered on both `ts-cube.moose-micro.ts.net` and its own name,
  assets included. **Superseded 2026-09-12**: homepage replaced glance
  (issue #291) — the homepage-shaped list above is what this page now
  describes, and its live checks re-run after the switch (the `homepage`
  short name additionally needs the `svc:homepage` Service object, see
  [the map](#the-map)).

**Not exercised:** the failure-mode steps above — they're derived from
failures that actually happened, not from breaking things deliberately
afterwards.

## See also

- [reverse-proxy](../categories/reverse-proxy.md) — Caddy, the certificate
  mechanism, and the Tailscale Services split.
- [reverse-proxy-history](../categories/reverse-proxy-history.md) — the
  retired path-prefix design and why it went.
- [landing](../categories/landing.md) — homepage, the index.
- [Using the forge](forgejo.md) — cloning, and the hostnames Forgejo hands out.
- [homelab README](README.md) — the other services on this tailnet.
- [hosts.md](../hosts.md) — `nire-cube` itself.
