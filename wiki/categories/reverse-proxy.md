# `reverse-proxy` — `nire/homelab/reverse-proxy/`

[Caddy](https://caddyserver.com/), one tailnet-only HTTPS front door for
every web service on `nire-cube`. Added 2026-08-24, cube-only.

Moved from `nire/reverse-proxy/` to `nire/homelab/reverse-proxy/` on
2026-08-27, nested under a new umbrella `homelab` category alongside six
other self-hosted-service categories — see
[categories/README.md](README.md). The category name is unaffected.

**Confirmed working end to end, 2026-08-24**, on the second switch. `just
switch` came up with 0 failed units, `caddy.service` `active (running)` at
`NRestarts=0`, and from *another* tailnet host (not `localhost` on cube):

| Request | Result |
|---|---|
| `https://ts-cube.<tailnet>.ts.net/grafana/` | 200, TLS validated |
| `https://ts-cube.<tailnet>.ts.net/git/` | 200, TLS validated |
| `https://ts-cube.<tailnet>.ts.net/` | 200 — [glance](landing.md), the service index |
| `https://ts-cube.<tailnet>.ts.net/git` | 301 → `/git/` |
| `http://ts-cube/` | 301 → the FQDN |

`ssl_verify_result` was 0 — the tailscaled-issued certificate validated
against the system trust store, which is the entire point of this category
and the one thing no amount of building could have shown. Forgejo's
*generated* links were checked separately (`href="/git/explore/repos"`, and
an asset under `/git/` returning 200), since a correctly stripped prefix can
still emit links that 404 on the next click. On the host, `ss -ltn` shows
3000 and 3001 bound to `127.0.0.1` only, with 80/443 the sole tailnet-facing
listeners.

**The first switch was broken**, and in an instructive way: `/grafana/`
returned 200 while `/git/` returned 404, because both routes had been given
the same Caddy directive. See [the two apps want opposite
things](#the-two-apps-want-opposite-things-from-the-proxy) below, and
[`lessons-learned.md`](<../../claude cave/lessons-learned.md>) #41 — every
static check had passed first, including a real build and a read of the
built artifact.

## What's in it

One file, `nixos`-class: `caddy/caddy.nix`.

## What it changed elsewhere

This category is not additive — it moved two existing services in the same
change:

| | Before | After |
|---|---|---|
| Grafana ([monitoring](monitoring.md)) | `0.0.0.0:3000`, `http://ts-cube:3000/` | `127.0.0.1:3000`, `https://ts-cube.<tailnet>.ts.net/grafana/` |
| Forgejo ([git-forge](git-forge.md)) | `0.0.0.0:3001`, `http://ts-cube:3001/` | `127.0.0.1:3001`, `https://ts-cube.<tailnet>.ts.net/git/` |

Both used to listen on every interface and rely entirely on
`trustedInterfaces = [ "tailscale0" ]` to keep the LAN out — a firewall
property, not a listener property. They are on loopback now and reachable
only through this proxy, so the firewall became the second line rather than
the only one. The old URLs do not answer.

`http://ts-cube/` (the bare MagicDNS name, port 80) redirects to the HTTPS
index, so the short name someone already has in muscle memory still lands
somewhere useful.

The root route was a plaintext `respond` placeholder for a few hours on
2026-08-24 and now proxies to [glance](landing.md) — which means these two
categories are a pair: dropping `landing` while keeping this one leaves the
front page returning 502.

## Certificates come from tailscaled, with no plugin

The mechanism is smaller than it looks, and was read out of Caddy's own
source in the pinned nixpkgs rather than assumed:

- `modules/caddyhttp/autohttps.go` defines `isTailscaleDomain` as nothing
  more than a `.ts.net` suffix check. Any site address matching it is pulled
  *out* of the normal ACME-managed set and given its own automation policy.
- That policy's certificate manager is
  `tls.get_certificate.tailscale` (`modules/caddytls/certmanagers.go`), which
  asks the **local tailscaled** for the certificate.

So there is no ACME account, no `email`, no DNS-01 credentials, and no
`caddy.withPlugins` rebuild with a vendor hash. Ordinary `pkgs.caddy` plus a
`.ts.net` site address is the whole thing.

Two prerequisites, neither of which lives in this repo:

- **`services.tailscale.permitCertUid = "caddy"`.** Not optional: tailscaled
  refuses certificate requests from non-root local-API clients unless the
  peer's uid matches `TS_PERMIT_CERT_UID` (`ipn/ipnserver/server.go`,
  `CanFetchCerts` — whose upstream comment names caddy as the intended
  case). The value is resolved by name at request time, so it tracks
  whatever uid `services.caddy`'s user ends up with.
- **HTTPS certificates enabled for the tailnet**, in Tailscale's admin
  console. Checked rather than assumed: `tailscale status --json` on
  `nire-lysithea`, 2026-08-24, reported a non-empty `CertDomains`, which is
  that setting being on. If it were off, every request here would fail the
  TLS handshake with nothing wrong in this repo — the same class of
  out-of-repo trap [system](system.md)'s `tailscale.nix` documents.

`permitCertUid` is set in `caddy.nix` itself, deliberately, rather than in
`system/networking/tailscale.nix`. That file is in the `system` category
*every* Linux host imports, so setting it there would grant cert-fetching
rights to a `caddy` user on durandal and tenacity — two hosts that
don't run Caddy. Scoping a change to the host that actually needs it is the
same call [virtualization](virtualization.md)'s VM fixes made.

## Paths, not subdomains, and that's forced

MagicDNS gives a device exactly **one** name. `grafana.ts-cube…` does not
resolve and cannot be made to without either Tailscale Services (`svc:`,
which needs per-service admin-console approval) or a real domain with split
DNS. So both apps are mounted under a path prefix on the one hostname, and
each has to be told about its own prefix:

- Grafana needs **both** `root_url` and `serve_from_sub_path`. `root_url`
  alone gives a UI whose CSS and JS 404 — broken-looking, not obviously
  misconfigured.
- Forgejo needs `ROOT_URL` with the path and a trailing slash. Its `DOMAIN`
  deliberately stays the short `ts-cube`, because that's what SSH clone URLs
  are built from and git+ssh doesn't pass through Caddy at all.

## The two apps want opposite things from the proxy

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
[`lessons-learned.md`](<../../claude cave/lessons-learned.md>) #41.

## Named matchers, not inline ones

`handle` accepts at most **one** matcher token, so the obvious

```caddyfile
handle /grafana /grafana/* { ... }
```

is a parse error: *"wrong argument count or unexpected line ending"*. The
working form is a named matcher:

```caddyfile
@grafana path /grafana /grafana/*
handle @grafana { ... }
```

This is the bug the `caddy adapt` run caught before the first switch. The
two-path form is deliberate over the shorter `/grafana*`, which would also
match `/grafanafoo`.

## The redirect vhost needs its scheme spelled out

The bare-name vhost is declared as `http://ts-cube`, and the `http://` is
load-bearing: it tells Caddy the site is HTTP-only and suppresses automatic
HTTPS for it. Without the scheme, Caddy would try to obtain a certificate
for the name `ts-cube` — which is not a `.ts.net` domain, so the Tailscale
manager declines it and it falls through to Caddy's internal CA, producing
an untrusted certificate on a name that only ever needed to redirect.

## Firewall, and binding 443 as a non-root user

No firewall change. 443 and 80 are **not** added to
`networking.firewall.allowedTCPPorts` — same reasoning
[monitoring](monitoring.md) and [git-forge](git-forge.md) each already spell
out for their own ports: `trustedInterfaces = [ "tailscale0" ]` lets tailnet
traffic bypass the allow-list, everything arriving on another interface hits
the default-deny. The usual caveat applies unchanged: that trusts the whole
interface, not a port.

Caddy itself still binds every interface, because it can't bind the tailnet
address — that IP is assigned at runtime by tailscaled and isn't knowable at
build time.

Binding 443 as the unprivileged `caddy` user works because upstream's own
`caddy.service` — which nixpkgs ships via `systemd.packages`, overriding only
`ExecStart` — carries
`AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE`. Read out of the
caddy dist tarball rather than assumed; nothing in this module grants it.

## Ordering against tailscaled

`systemd.services.caddy.after = [ "tailscaled.service" ]`, ordering only —
tailscaled is enabled unconditionally by `system`, so there's nothing to
pull in. What it avoids is the narrow startup window where Caddy asks a
not-yet-running tailscaled for a certificate. The Tailscale certificate
manager is consulted per-handshake, so getting this wrong would mean early
requests failing and later ones working: intermittent and easy to misread,
rather than a clean failure.

## No persistence entry

Same reasoning [monitoring](monitoring.md), [git-forge](git-forge.md) and
[shortlinks](shortlinks.md) each give: `nire-cube` has a plain persistent
root, not the `/root` wipe durandal/tenacity get
(`cube-configuration.nix`'s header), so `/var/lib/caddy` — certificates and
Caddy's own state — survives reboots with no `environment.persistence`
entry. If this module is ever imported by a host that DOES wipe root, add
one first, modeled on `tailscale-persist.nix`; otherwise every boot
re-fetches certificates from tailscaled.

## Why the category isn't named `caddy`

Same reason [git-forge](git-forge.md) isn't `forgejo` and
[shortlinks](shortlinks.md) isn't `golink`: a category and its one module
both declaring `caddy` would both write `flake.modules.nixos.caddy` and
silently **merge** rather than error — the `containers`/`podman.nix`
collision [architecture.md](../architecture.md) documents, hit for real
twice in this tree already.

## Imported by

`nire-cube` only, as of 2026-08-24. Confirmed not to move durandal,
tenacity or lysithea: each host's toplevel `drvPath` is byte-identical
before and after this change.

## See also

- [monitoring](monitoring.md) — Grafana, one of the two things behind this
  proxy, and the settings it needed for the path prefix.
- [git-forge](git-forge.md) — Forgejo, the other one, and why its `DOMAIN`
  and `ROOT_URL` now disagree on purpose.
- [shortlinks](shortlinks.md) — golink, the service that is deliberately
  *not* behind this: it embeds tsnet and joins the tailnet as its own
  device.
- [system](system.md) — `tailscale.nix`, for the firewall rule this rests
  on and the two out-of-repo tailnet traps.
- [homelab/README.md](../homelab/README.md) — the usage side: the current
  URLs for everything on cube.
- [hosts.md](../hosts.md) — current switch/verification status for
  `nire-cube`.
