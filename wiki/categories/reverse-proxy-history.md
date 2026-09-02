# `reverse-proxy` — history

## Contents

- [Confirmed working end to end, 2026-08-24](#confirmed-working-end-to-end-2026-08-24)
- [See also](#see-also)

The verification record for [reverse-proxy](reverse-proxy.md)'s second
switch, split out 2026-09-03. What actually broke on the first switch, and
why, is still on the main page — [the two apps want opposite
things](reverse-proxy.md#the-two-apps-want-opposite-things-from-the-proxy)
— since that's current mechanism, not just history.

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
things](reverse-proxy.md#the-two-apps-want-opposite-things-from-the-proxy)
for the mechanism, and [`lessons-learned.md`](../lessons-learned.md) #41
for the general shape of the mistake.

## See also

- [reverse-proxy](reverse-proxy.md) — the mechanism as it works today.
