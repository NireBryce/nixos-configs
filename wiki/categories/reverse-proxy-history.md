# `reverse-proxy` — history

_Last modified: 2026-10-20_

This page records [reverse-proxy](reverse-proxy.md)'s second-switch
verification (split out 2026-09-03), the retired path-prefix routing design
(retired 2026-09-07, moved here 2026-09-12 once each app had its own
Tailscale Services vhost), and the 2026-09-07 to 09-11 moves and TLS outage
(moved here from the main page 2026-10-20).

## Contents

- [Confirmed working end to end, 2026-08-24](#confirmed-working-end-to-end-2026-08-24)
- [Paths, not subdomains, was the original constraint — Tailscale Services lifted it, partially](#paths-not-subdomains-was-the-original-constraint--tailscale-services-lifted-it-partially)
- [The two apps want opposite things from the proxy (historical)](#the-two-apps-want-opposite-things-from-the-proxy-historical)
- [The retired routes, as they were](#the-retired-routes-as-they-were)
- [The first Tailscale Services attempt, 2026-09-07](#the-first-tailscale-services-attempt-2026-09-07)
- [The 2026-09-07 to 09-11 moves and outage](#the-2026-09-07-to-09-11-moves-and-outage)
- [See also](#see-also)

## Confirmed working end to end, 2026-08-24

On the second switch. `just switch` came up with 0 failed units,
`caddy.service` `active (running)` at `NRestarts=0`, and from *another*
tailnet host (not `localhost` on cube):

| Request | Result |
|---|---|
| `https://ts-cube.moose-micro.ts.net/grafana/` | 200, TLS validated |
| `https://ts-cube.moose-micro.ts.net/git/` | 200, TLS validated |
| `https://ts-cube.moose-micro.ts.net/` | 200 — glance, the service index (since removed) |
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
`flake/modules/general-config/homelab/reverse-proxy/tailscale-services/README.md` for
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

This is the one thing that was wrong, and it cost a switch.
Both routes were given `handle`, which passes the matched path through
untouched. `/grafana/` returned 200; `/git/` returned **404**.

- **Grafana**, with `serve_from_sub_path`, serves *under*
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

## The 2026-09-07 to 09-11 moves and outage

Moved here from the top of [reverse-proxy](reverse-proxy.md) so that page opens with what the category is. Statuses below are as of the dated entries; `svc:glance` was removed 2026-10-19.

**Confirmed working end to end, 2026-08-24**, on the second switch — the
first served `/git/` a 404 through the wrong Caddy directive, because
Grafana and Forgejo wanted opposite `handle`/`handle_path` treatment for
the path prefix they then shared; see
[reverse-proxy-history.md](reverse-proxy-history.md#the-two-apps-want-opposite-things-from-the-proxy-historical)
for that mechanism and the full verification checklist (TLS validation,
generated-link checks, the exact requests tested).

**Grafana and Forgejo moved again, 2026-09-07**, off the shared
`ts-cube.../grafana/`, `.../git/` paths onto their own Tailscale Services
names — `https://grafana.moose-micro.ts.net/`,
`https://git.moose-micro.ts.net/`. Caddy is still what terminates TLS for
both: Tailscale Services turned out not to support declarative HTTPS
termination on this tailscale version (a confirmed upstream bug, not a
config mistake — see `tailscale-services/serve.nix`'s history section for
the full investigation, including the two tailscale/tailscale issue
numbers). Confirmed working end to end the same day: valid TLS on both new
names, old paths correctly 404, Forgejo's own generated links using the new
`ROOT_URL`.

**Then all tailnet HTTPS on cube broke, 2026-09-08 to 2026-09-10**, and the
two "confirmed working" snapshots above are both older than the break. The
bare-name convenience vhosts added 2026-09-08 (`https://git` and friends,
each with `tls internal`) made Caddy's Caddyfile adapter emit an explicit
`automation.policies` entry covering the `.ts.net` names too — and an
explicit policy suppresses Caddy's automatic "this is a Tailscale domain,
ask tailscaled for the cert" detection, leaving those names pointed at
public Let's Encrypt, which can never issue for a tailnet name. Every
`.ts.net` handshake died with `SSL_ERROR_INTERNAL_ERROR_ALERT`, including
`ts-cube.moose-micro.ts.net`, which no commit had touched. `caddy.nix`'s
`tailscaleCert` binding carries the mechanism with `file:line` references
into caddy 2.11.4's source; [§47](../lessons-learned/47-explicit-setting-disables-implicit-one.md)
is the full account. The fix
is naming `get_certificate tailscale` on each `.ts.net` vhost explicitly
rather than relying on the detection. **Runtime-verified on hardware
2026-09-11**: from tenacity, every name returns validated TLS
(`tls_verify_result` 0) — `ts-cube` 200, `git` 200, `grafana` 302, `glance`
200.

Two things the same investigation turned up:

- **`svc:glance` never existed — created 2026-09-10, one step still
  pending.** PR #211 landed the `serve.nix` forward and the Caddy vhost, and
  `acl-diff-applied.hujson` recorded the autoApprover, but the policy file
  was never POSTed and the `svc:` object was never PUT, so
  `glance.moose-micro.ts.net` did not resolve at all while git and grafana
  did. Now created, along with the `grants` entry the other two services
  each had; `just tailscale-acl diff` reports "no difference" for the first
  time since 2026-09-09, and the name resolves tailnet-wide. Fixed 2026-09-11,
  but restarting `tailscale-serve` was not what fixed it (tried twice, both
  clean, no change). Re-running `serve set-config` against an
  already-standing advertisement does not activate a newly-created
  Service — cube had carried `svc:glance` in its serve config since
  2026-09-09, long before the object existed to approve it against. A fresh
  registration is what the control plane acts on: `systemctl restart
  tailscaled`, then `tailscale-serve` after it (per #267). All four names
  now return validated TLS. Beware `vip-get glance` as an existence check:
  the API path wants the `svc:` prefix, and without it every service 404s,
  `svc:grafana` included.

- **`tailscale-serve.service` lost the race on boot** — issue #267, fixed
  2026-09-11 and closed. It failed `unexpected state: NoState` 34ms into the
  2026-09-09 boot and, being a `oneshot` with no retry, stayed failed for
  9.5 hours until a switch happened to re-run it: no `svc:` forwards at all
  in the meantime, while cube's own name kept working. `serve.nix` now sets
  `Restart=on-failure` with a `StartLimit` pair — legal on `Type=oneshot`
  (only `always`/`on-success` are rejected), so it retries the race and
  still gives up on a persistent failure. The upstream unit gates on
  tailscaled the *process*, not its backend state, which is what makes the
  race possible at all. **Not yet observed self-healing on a real boot** —
  the fix is reasoned from `systemd.service(5)` and the failure it
  reproduces, not from watching a reboot recover.

## See also

- [reverse-proxy](reverse-proxy.md) — the mechanism as it works today.
- [`caddy.nix`](../../flake/modules/homelab-config/homelab/reverse-proxy/caddy/caddy.nix)
  — its header carries the live mechanism; this page carries what it
  stopped doing.
