# `reverse-proxy` — `nire/homelab/reverse-proxy/`

_Last modified: 2026-09-11_

## Contents

- [What's in it](#whats-in-it)
- [What it changed elsewhere](#what-it-changed-elsewhere)
- [Certificates come from tailscaled, with no plugin](#certificates-come-from-tailscaled-with-no-plugin)
- [Paths, not subdomains, was the original constraint — Tailscale Services lifted it, partially](#paths-not-subdomains-was-the-original-constraint--tailscale-services-lifted-it-partially)
- [Fronting Tailscale Services with Caddy](#fronting-tailscale-services-with-caddy)
- [The two apps want opposite things from the proxy (historical)](#the-two-apps-want-opposite-things-from-the-proxy-historical)
- [Named matchers, not inline ones](#named-matchers-not-inline-ones)
- [The redirect vhost needs its scheme spelled out](#the-redirect-vhost-needs-its-scheme-spelled-out)
- [Firewall, and binding 443 as a non-root user](#firewall-and-binding-443-as-a-non-root-user)
- [Ordering against tailscaled](#ordering-against-tailscaled)
- [No persistence entry](#no-persistence-entry)
- [Why the category isn't named `caddy`](#why-the-category-isnt-named-caddy)
- [Imported by](#imported-by)
- [See also](#see-also)

[Caddy](https://caddyserver.com/), one tailnet-only HTTPS front door for
every web service on `nire-cube`. Added 2026-08-24, cube-only; nested under
the `homelab` umbrella since 2026-08-27 (name unaffected).

**Confirmed working end to end, 2026-08-24**, on the second switch — the
first served `/git/` a 404 through the wrong Caddy directive; see [the two
apps want opposite things](#the-two-apps-want-opposite-things-from-the-proxy-historical)
below for that mechanism (now historical, see the next section), and
[reverse-proxy-history.md](reverse-proxy-history.md) for the full
verification checklist (TLS validation, generated-link checks, the exact
requests tested).

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
header has the full mechanism, read out of caddy 2.11.4's source; the fix
is naming `get_certificate tailscale` on each `.ts.net` vhost explicitly
rather than relying on the detection. **Runtime-verified on hardware
2026-09-11**: from tenacity, every name returns validated TLS
(`tls_verify_result` 0) — `ts-cube` 200, `git` 200, `grafana` 302, `glance`
200.

The bare-name vhosts come in two flavours, and the difference matters:

- **`http://git`** and friends redirect with no certificate involved at
  all, landing on the real publicly-valid tailnet cert — no warning
  anywhere. These were *unreachable* from the day they were written until
  2026-09-11 (issue #272): a `svc:` name is a Service VIP that answers only
  on the ports its Service object and `serve.nix` both declare, and all
  three declared `tcp:443` only. `http://ts-cube` worked throughout, being
  a real device address where Caddy binds 80 directly — which is what made
  the gap easy to miss. Fixed by adding `tcp:80` to both halves.
- **`https://git`** and friends show `SEC_ERROR_UNKNOWN_ISSUER`, and that
  is `tls internal` working as designed, not a leftover bug — they serve
  Caddy's own local CA. They exist to catch browsers that force HTTPS
  before the `http://` redirect gets a chance. Short of trusting that CA on
  every client there is no improving them, and they were deliberately kept
  rather than dropped once `http://` worked.

Two things the same investigation turned up, both still open:

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

- **`tailscale-serve.service` loses the race on boot** — issue #267. It
  failed `unexpected state: NoState` 34ms into the 2026-09-09 boot and,
  being a `oneshot` with no retry, stayed failed for 9.5 hours until a
  switch happened to re-run it. Nothing about the unit makes this
  self-healing across a reboot, which also means the glance step above
  will not survive one.

## What's in it

Two files, `nixos`-class: `caddy/caddy.nix` and
`tailscale-services/serve.nix` (the latter added 2026-09-07 — raw TCP
forwarding only, not HTTPS termination; see below).

## What it changed elsewhere

This category is not additive — it moved two existing services, twice:

| | 2026-08-24 | 2026-09-07 |
|---|---|---|
| Grafana ([monitoring](monitoring.md)) | `0.0.0.0:3000`, `http://ts-cube:3000/` → `127.0.0.1:3000`, `https://ts-cube.moose-micro.ts.net/grafana/` | → `https://grafana.moose-micro.ts.net/` (still `127.0.0.1:3000`) |
| Forgejo ([git-forge](git-forge.md)) | `0.0.0.0:3001`, `http://ts-cube:3001/` → `127.0.0.1:3001`, `https://ts-cube.moose-micro.ts.net/git/` | → `https://git.moose-micro.ts.net/` (still `127.0.0.1:3001`) |

Both used to listen on every interface and rely entirely on
`trustedInterfaces = [ "tailscale0" ]` to keep the LAN out — a firewall
property, not a listener property. They've been on loopback since the first
move; only the tailnet-facing name changed the second time. Every prior URL
in the table above stopped answering (404) as of its own move.
`http://ts-cube/` (bare MagicDNS name) redirects to the HTTPS index, so the
short name still lands somewhere useful.

The root route proxies to [glance](landing.md) — these two categories are a
pair: dropping `landing` while keeping this one leaves the front page
returning 502.

## Certificates come from tailscaled, with no plugin

Read out of Caddy's own source in the pinned nixpkgs rather than assumed:
`modules/caddyhttp/autohttps.go`'s `isTailscaleDomain` is a `.ts.net`
suffix check — any matching site address is pulled out of the ACME-managed
set and given a `tls.get_certificate.tailscale` policy
(`modules/caddytls/certmanagers.go`), which asks the **local tailscaled**
for the certificate. No ACME account, no `email`, no DNS-01 credentials, no
`caddy.withPlugins` rebuild — ordinary `pkgs.caddy` plus a `.ts.net` site
address is the whole thing.

Two prerequisites, neither in this repo:

- **`services.tailscale.permitCertUid = "caddy"`.** tailscaled refuses
  certificate requests from non-root local-API clients unless the peer's
  uid matches `TS_PERMIT_CERT_UID` (`ipn/ipnserver/server.go`,
  `CanFetchCerts`). The value resolves by name at request time, so it
  tracks whatever uid `services.caddy`'s user gets.
- **HTTPS certificates enabled for the tailnet** in Tailscale's admin
  console. Checked, not assumed: `tailscale status --json` reported a
  non-empty `CertDomains` (2026-08-24). Off, every request here fails the
  TLS handshake with nothing wrong in this repo — same class of
  out-of-repo trap [system](system.md)'s `tailscale.nix` documents.

`permitCertUid` is set in `caddy.nix` rather than in
`system/networking/tailscale.nix` — that file is in the `system` category
*every* Linux host imports, and setting it there would grant cert-fetching
rights to a `caddy` user on hosts that don't run Caddy. Scope a change to
the host that needs it.

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
[fronting Tailscale Services with Caddy](#fronting-tailscale-services-with-caddy)
below — just per-service instead of per-path.

## Fronting Tailscale Services with Caddy

`tailscale-services/serve.nix` configures each service's `endpoints` with
a `tcp://` backend scheme — raw byte forwarding, no HTTP interpretation —
pointed at Caddy's own loopback address, `127.0.0.1:443`. tailscaled
forwards the untouched TLS bytes (SNI ClientHello included) from each
service's virtual address; Caddy picks the right vhost by SNI, same
mechanism it already used to be the one thing on this host bound to 443,
now serving three names instead of one
(`ts-cube`/`grafana`/`git.moose-micro.ts.net`). Each new vhost is a plain
`reverse_proxy` with no path matcher — the app has the whole vhost to
itself, so `handle`/`handle_path` don't come up at all for these two.

The obvious-looking alternative — `endpoints."tcp:443" = "http://127.0.0.1:
PORT"`, pointed straight at Grafana/Forgejo, letting tailscaled terminate
HTTPS itself the way it does for a device's own MagicDNS name — does not
work. `tailscale serve status` showed plain `http://` on port 443, not a
display quirk (confirmed: a raw HTTP request reached Grafana correctly,
a TLS handshake against the same address:port failed outright). Root cause,
confirmed against tailscale/tailscale's own tracker: **#18381** (open) —
`serve set-config`/`get-config`, exactly what nixpkgs'
`services.tailscale.serve` module uses, always drops HTTPS status to plain
HTTP on round-trip; **#18219** confirms the raw CLI *can* set real HTTPS
but that state doesn't survive `set-config` or a reboot. The fix,
**PR #20116**, was an unmerged draft as of this check.

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
tailscaled is enabled unconditionally by `system`. What it avoids is the
startup window where Caddy asks a not-yet-running tailscaled for a
certificate. The manager is consulted per-handshake, so getting this wrong
means early requests failing and later ones working: intermittent, easy to
misread.

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
- [reverse-proxy-history.md](reverse-proxy-history.md) — the second
  switch's full verification checklist.
