# `git-forge` — history

## Contents

- [First switch and the move behind Caddy](#first-switch-and-the-move-behind-caddy)
- [The brief `0.0.0.0` window](#the-brief-0000-window)
- [See also](#see-also)

Verification record for [git-forge](git-forge.md) as it was first switched
and then re-routed, split out 2026-09-03 so that page stays about the
category as it works today.

## First switch and the move behind Caddy

Confirmed working end to end on the first real switch, 2026-08-24: `just
switch` came up with 0 failed units, `forgejo-secrets.service` exited
`0/SUCCESS`, `forgejo.service` stayed `active (running)` past its first
40s, and `http://ts-cube:3001/` answered `HTTP 200` from another tailnet
host.

That URL stopped being current the same day: Forgejo moved behind Caddy
([reverse-proxy](reverse-proxy.md)), listening on `127.0.0.1:3001` and
reached at `https://ts-cube.moose-micro.ts.net/git/` instead. The proxied
arrangement was confirmed working too, same day — 200 over validated TLS
from another tailnet host, generated links carrying `/git/`, assets
loading. Getting there took a second switch: the first served Forgejo the
un-stripped prefix and it 404'd everything —
[reverse-proxy](reverse-proxy.md) has that writeup. Git+ssh over the
host's own OpenSSH was not exercised in this pass; only the HTTP side was
confirmed.

## The brief `0.0.0.0` window

Forgejo bound `0.0.0.0` for its first few hours (2026-08-24), when
`trustedInterfaces = [ "tailscale0" ]` ([system](system.md)) was the only
thing between port 3001 and the LAN. It binds `127.0.0.1` now, with Caddy
the only client. `forgejo.nix`'s own history note has the before/after.

One knock-on the move fixed quietly: `LOCAL_ROOT_URL` defaults to
`http://%(HTTP_ADDR)s:%(HTTP_PORT)s/` and nixpkgs doesn't override it, so
under `0.0.0.0` it built self-referential URLs from an any-address; it
resolves to `http://127.0.0.1:3001/` now.

## See also

- [git-forge](git-forge.md) — the category as it works today.
- [reverse-proxy](reverse-proxy.md) — Caddy, and the prefix-stripping
  incident that took two switches to get right.
