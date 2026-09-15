# `reverse-proxy` — history

_Last modified: 2026-09-14_

The verification record for [reverse-proxy](reverse-proxy.md)'s second
switch, split out 2026-09-03, plus the path-prefix routing design (retired
2026-09-07, moved here 2026-09-12 once each app got its own Tailscale
Services vhost and there was no longer a shared prefix for the design to
justify).

## Contents

- [Confirmed working end to end, 2026-08-24](#confirmed-working-end-to-end-2026-08-24)
- [Paths, not subdomains, was the original constraint — Tailscale Services lifted it, partially](#paths-not-subdomains-was-the-original-constraint--tailscale-services-lifted-it-partially)
- [The two apps want opposite things from the proxy (historical)](#the-two-apps-want-opposite-things-from-the-proxy-historical)
- [The retired routes, as they were](#the-retired-routes-as-they-were)
- [The first Tailscale Services attempt, 2026-09-07](#the-first-tailscale-services-attempt-2026-09-07)
- [See also](#see-also)

## Confirmed working end to end, 2026-08-24

On the second switch. `just switch` came up with 0 failed units,
`caddy.service` `active (running)` at `NRestarts=0`, and from *another*
tailnet host (not `localhost` on cube):

| Request | Result |
|---|---|
| `https://ts-cube.moose-micro.ts.net/grafana/` | 200, TLS validated |
| `https://ts-cube.moose-micro.ts.net/git/` | 200, TLS validated |
| `https://ts-cube.moose-micro.ts.net/` | 200 — [glance](landing.md), the service index |
| `https://ts-cube.moose-micro.ts.net/git` | 301 → `/git/` |
| `http://ts-cube/` | 301 → the FQDN |

`ssl_verify_result` was 0 — the tailscaled-issued certificate validated
against the system trust store, the one thing no amount of building could
have shown. Forgejo's *generated* links were checked separately
(`href="/git/explore/repos"`, an asset under `/git/` returning 200), since a
correctly stripped prefix can still emit links that 404 on the next click.
On the host, `ss -ltn` showed 3000/3001 bound to `127.0.0.1` only, with
80/443 the sole tailnet-facing listeners.

The first switch was broken, instructively: `/grafana/` returned 200
while `/git/` returned 404, because both routes had been given the same
Caddy directive — every static check had passed first, including a real
build and a read of the built artifact. See [the two apps want opposite
things](#the-two-apps-want-opposite-things-from-the-proxy-historical)
for the mechanism, and [`lessons-learned.md`](../lessons-learned.md) #41
for the general shape of the mistake.

## Paths, not subdomains, was the original constraint — Tailscale Services lifted it, partially

MagicDNS gives a device exactly **one** name, which is why both apps
originally mounted under a path prefix on `ts-cube`'s one hostname
(`root_url`/`serve_from_sub_path` for Grafana, `ROOT_URL` for Forgejo — see
each app's own file for the by-then-retired mechanics, kept as history).

**Tailscale Services (`svc:`) reopened this 2026-09-07** — see
`wiki/open-threads.md`'s entry and
`flake/modules/system/homelab/reverse-proxy/tailscale-services/README.md` for
the ACL/tag/service-object side (a separate, API-managed resource, not
declared in this repo's Nix). Each app now has its own tailnet DNS name
with no path prefix. What Services did **not** solve, discovered live: it
cannot terminate HTTPS declaratively on this tailscale version (confirmed
upstream bug — `tailscale-services/serve.nix`'s history section has the
full trail, including the exact failing commands and the two
tailscale/tailscale issue numbers). So Caddy is still in the loop — see
[reverse-proxy.md](reverse-proxy.md#fronting-tailscale-services-with-caddy)
— just per-service instead of per-path.

## The two apps want opposite things from the proxy (historical)

**Retired 2026-09-07** along with the path-prefix routes themselves —
each app has its own vhost now, so there's no shared prefix for `handle`
vs `handle_path` to disagree about. Kept for the mechanism, and in case
either move ever needs reverting — [the routes themselves](#the-retired-routes-as-they-were)
are below, moved out of `caddy.nix`'s header 2026-09-13.

This is the one thing that was actually gotten wrong, and it cost a switch.
Both routes were given `handle`, which passes the matched path through
untouched. `/grafana/` returned 200; `/git/` returned **404**.

- **Grafana**, with `serve_from_sub_path`, genuinely serves *under*
  `/grafana`, so the prefix must be **left on** → `handle`.
- **Forgejo** has no equivalent option. It always serves at `/` — confirmed
  on the host rather than inferred: `curl 127.0.0.1:3001/` is 200,
  `curl 127.0.0.1:3001/git/` is 404 — so the prefix must be **stripped** →
  `handle_path`. Its `ROOT_URL` still carries `/git/`, which is what makes
  the links it *generates* point back through the prefix. Same thing
  Gitea/Forgejo's own nginx docs encode in the trailing slash of
  `proxy_pass http://…:3001/;`, which reads as cosmetic and isn't.

`handle_path` takes an inline path matcher only — a named matcher is
rejected — so the bare `/git` can't ride along in one matcher the way
`@grafana`'s two paths do, and gets its own `redir` to `/git/` instead.

The general form of the mistake, and why every static check missed it, is
[`lessons-learned.md`](../lessons-learned.md) #41.

## The retired routes, as they were

Verbatim from `caddy.nix`'s `ts-cube.moose-micro.ts.net` vhost, as it stood
2026-08-24 to 2026-09-07. `${tailnetFqdn}` is the Nix binding for that same
name:

```caddyfile
@grafana path /grafana /grafana/*
handle @grafana {
    reverse_proxy 127.0.0.1:3000
}

@gitbare path /git
handle @gitbare {
    redir https://${tailnetFqdn}/git/ permanent
}
handle_path /git/* {
    reverse_proxy 127.0.0.1:3001
}
```

**Named matchers, not inline ones, for `@grafana`**: `handle` accepts at
most *one* matcher token, so `handle /grafana /grafana/*` is a parse error
(*"wrong argument count or unexpected line ending"*) — caught by running the
generated Caddyfile through `caddy adapt` before shipping. The two-path form
was deliberate over `/grafana*`, which would also match `/grafanafoo`.
`handle_path` took an **inline** path matcher only — a named matcher was
rejected — so the bare `/git` couldn't ride along the way `@grafana`'s two
paths did, hence its own `redir` block.

Getting the two live took two switches. `nix eval`, `just modules`,
`caddy adapt`, a real build and reading the built artifact back all passed
on the first one; only a live request found the `handle`/`handle_path`
asymmetry.

## The first Tailscale Services attempt, 2026-09-07

Moved out of `serve.nix`'s history section 2026-09-14. The **rule** this
produced is live and lives on [reverse-proxy.md](reverse-proxy.md#fronting-tailscale-services-with-caddy);
what follows is how it was established, kept because "just point the endpoint
at the app" is the obvious thing to try again.

The first version set each service's endpoint to `http://127.0.0.1:PORT`,
pointed straight at Grafana and Forgejo with no Caddy involved — the form the
upstream NixOS module's own option documentation uses as its example. The
design assumed tailscaled would terminate HTTPS for a `svc:` name the same
way it does for a device's own MagicDNS name.

It does not. `tailscale serve status` showed
`http://grafana.moose-micro.ts.net:443` — plain HTTP, and not a display
quirk: a raw non-TLS HTTP request reached Grafana correctly (a real
`302 → /login`) while a TLS handshake against the same address and port
failed with *"wrong version number"*, nothing speaking TLS there at all.
Setting it through the CLI directly rather than the config file —
`tailscale serve --service=svc:grafana --bg --https=443 http://127.0.0.1:3000`,
run with sudo on cube — left `tailscale serve status` showing `http://`
unchanged.

Root cause, confirmed against tailscale/tailscale's tracker rather than
guessed:

- **#18381** (open at the time) — `serve set-config`/`get-config`, the exact
  JSON-file mechanism nixpkgs' `services.tailscale.serve` uses, always
  round-trips a service endpoint back as `"tcp:443": "http://..."`,
  discarding HTTPS status regardless of what was configured.
- **#18219** (closed as a duplicate) — the raw CLI *can* set real HTTPS
  (`"HTTPS": true`), but that state survives neither a `get-config`/
  `set-config` round trip nor, per the reporter, a reboot. Useless for a
  declarative config either way.
- **PR #20116**, the proposed fix, was an unmerged draft against a tailscale
  newer than the pinned 1.102.2.

Hence the shape `serve.nix` has now: `tcp://` raw forwarding to Caddy's
loopback listener, with Caddy terminating TLS and picking the vhost by SNI.

## See also

- [reverse-proxy](reverse-proxy.md) — the mechanism as it works today.
- [`caddy.nix`](../../flake/modules/system/homelab/reverse-proxy/caddy/caddy.nix)
  — its header carries the live mechanism; this page carries what it
  stopped doing.
