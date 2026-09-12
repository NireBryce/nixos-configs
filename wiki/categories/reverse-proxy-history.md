# `reverse-proxy` — history

_Last modified: 2026-09-12_

The verification record for [reverse-proxy](reverse-proxy.md)'s second
switch, split out 2026-09-03, plus the path-prefix routing design (retired
2026-09-07, moved here 2026-09-12 once each app got its own Tailscale
Services vhost and there was no longer a shared prefix for the design to
justify).

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
`flake/modules/nire/homelab/reverse-proxy/tailscale-services/README.md` for
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
either move ever needs reverting (`caddy.nix`'s own history section has
the exact retired route blocks).

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

## See also

- [reverse-proxy](reverse-proxy.md) — the mechanism as it works today.
