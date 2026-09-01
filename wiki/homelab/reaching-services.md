# Reaching cube's services

## Contents

- [The map](#the-map)
- [What changed on 2026-08-24, and what to do about muscle memory](#what-changed-on-2026-08-24-and-what-to-do-about-muscle-memory)
- [Why it's HTTPS, and why the certificate is trusted](#why-its-https-and-why-the-certificate-is-trusted)
- [When something doesn't answer](#when-something-doesnt-answer)
- [Adding another service to this](#adding-another-service-to-this)
- [What's verified here](#whats-verified-here)
- [See also](#see-also)

Everything `nire-cube` serves over the web now lives under **one hostname,
one certificate, one port**. This page is about *using* that — the URLs, why
they're HTTPS, and what to check when one doesn't answer. For how it's
built, see [reverse-proxy](../categories/reverse-proxy.md).

## The map

| What | URL |
|---|---|
| Service index (glance) | `https://ts-cube.moose-micro.ts.net/` |
| Grafana | `https://ts-cube.moose-micro.ts.net/grafana/` |
| Forgejo | `https://ts-cube.moose-micro.ts.net/git/` |
| Anything, short form | `http://ts-cube/` → redirects to the above |
| golink (**not** on cube) | `http://go/` — see [creating go/ links](golinks.md) |

**Start at the root.** glance lists all three, live-checks each one, and shows
cube's CPU/memory/disk — so "what's running and is it up" is answered by
looking, not by reading this page.

`ts-cube`, **not** `nire-cube`: this tailnet renames its devices. That trap
has its own writeup in `system/networking/tailscale.nix`, indexed from
[system](../categories/system.md).

## What changed on 2026-08-24, and what to do about muscle memory

These no longer answer at all:

| Old | New |
|---|---|
| `http://ts-cube:3000/` | `https://ts-cube.moose-micro.ts.net/grafana/` |
| `http://ts-cube:3001/` | `https://ts-cube.moose-micro.ts.net/git/` |

Both services moved to loopback — they're reachable only through Caddy now,
which is the point: a firewall mistake no longer exposes them, because
they aren't listening anywhere a mistake could reach.

If you have the old ports bookmarked, `http://ts-cube/` is the shortest thing
to retrain on. It redirects, and it's four characters.

## Why it's HTTPS, and why the certificate is trusted

The certificate is issued by **Tailscale**, fetched by Caddy from the local
`tailscaled`. No ACME account, no self-signed warning, no certificate to
install on your devices — `*.ts.net` names get real, publicly-trusted certs,
and browsers accept them the same as any other site.

Two things follow that are worth knowing as a user:

- **It only works on the tailnet.** The name doesn't resolve elsewhere, and
  nothing is exposed to the internet. This is not Funnel.
- **The full FQDN matters for the certificate**, which is why the URLs above
  are `ts-cube.moose-micro.ts.net` and not just `ts-cube`. The short name
  works, it just redirects to the long one first.

## When something doesn't answer

Work down this list; it's ordered by what's most often actually wrong.

1. **Is your device on the tailnet?** `tailscale status` on the machine
   you're browsing from. Everything here is tailnet-only.
2. **Does the root page load?** If `https://ts-cube.moose-micro.ts.net/`
   works but `/git/` doesn't, Caddy is fine and the app is the problem — skip
   to 4. If the root is dead too, Caddy or the host is the problem.
3. **Is cube up?** `ping ts-cube`, or check the admin console. A `tailscale
   ping` that works while HTTP doesn't can also mean a tailnet ACL is
   blocking peer traffic — fixed in the Tailscale admin console, not in this
   repo.
4. **Ask the host**, over ssh:
   ```sh
   systemctl status caddy grafana forgejo glance
   systemctl list-units --state=failed
   ```
   `NRestarts` is the number to look at, not just `active` — a service that
   crashes and restarts in a loop reports `active` between restarts.
5. **Check the journal for the one that's failing**, `journalctl -u <unit> -n
   50`. Certificate problems show up in `caddy`'s journal specifically.

A 404 from a path that used to work is worth distinguishing from a dead
service: if the page you get is the app's own 404 rather than glance's index,
the request reached the app and the *routing* is wrong. That exact failure
happened to `/git/` on 2026-08-24 —
[reverse-proxy](../categories/reverse-proxy.md#the-two-apps-want-opposite-things-from-the-proxy)
has the mechanism.

## Adding another service to this

Short version: it binds loopback, gets a path prefix, and needs to be told
which prefix — and whether the proxy strips it or not depends on the app.
The long version, including the port registry and the verification ladder, is
the `new-homelab-service` skill.

## What's verified here

Exercised against the live instance on 2026-08-24 from `nire-lysithea`, over
the tailnet: all three URLs returning `HTTP 200` with `ssl_verify_result 0`
(i.e. the certificate validated against the system trust store, not merely
presented), `http://ts-cube/` returning 301, and `/git` (no trailing slash)
returning 301 to `/git/`.

**Not exercised:** any of the failure-mode steps above — they're derived from
the failures that actually happened during setup, not from breaking things
deliberately afterwards.

## See also

- [reverse-proxy](../categories/reverse-proxy.md) — Caddy, the certificate
  mechanism, and the prefix asymmetry.
- [landing](../categories/landing.md) — glance, the index at `/`.
- [Using the forge](forgejo.md) — cloning, and the two different hostnames
  Forgejo hands out.
- [homelab README](README.md) — the other services on this tailnet.
- [hosts.md](../hosts.md) — `nire-cube` itself.
