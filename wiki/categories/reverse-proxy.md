# `reverse-proxy` — `homelab-config/homelab/reverse-proxy/`

_Last modified: 2026-10-25_

[Caddy](https://caddyserver.com/), one tailnet-only HTTPS front door for
every web service on `nire-cube`. Cube-only; added 2026-08-24, under the
`homelab` umbrella since 2026-08-27.

Each app has its own Tailscale Services name (`https://grafana.moose-micro.ts.net/`,
`https://git.moose-micro.ts.net/`) and Caddy terminates TLS for it, because
Tailscale Services can't terminate HTTPS declaratively on this tailscale
version (a confirmed upstream bug; `tailscale-services/serve.nix`'s history
section has the investigation and the two tailscale/tailscale issue numbers).
Certificates come from tailscaled, and every `.ts.net` vhost names
`get_certificate tailscale` explicitly (see below). Runtime-verified on
hardware 2026-09-11: from tenacity, every name returns validated TLS.
The incidents behind this setup, including the 2026-09-08 to 09-10 outage,
are in [reverse-proxy-history.md](reverse-proxy-history.md#the-2026-09-07-to-09-11-moves-and-outage).

> **Condensed version:**
> [reverse-proxy-for-agents.md](reverse-proxy-for-agents.md) — the same
> ground with the narrative stripped out, for an agent (or a human in
> a hurry) loading it mid-task. Both siblings get edited in the same
> change.

## Contents

- [Category contents](#category-contents)
- [What it changed elsewhere](#what-it-changed-elsewhere)
- [Bare-name vhosts](#bare-name-vhosts)
- [Certificates come from tailscaled, with no plugin](#certificates-come-from-tailscaled-with-no-plugin)
- [Fronting Tailscale Services with Caddy](#fronting-tailscale-services-with-caddy)
- [Named matchers, not inline ones](#named-matchers-not-inline-ones)
- [The redirect vhost needs its scheme spelled out](#the-redirect-vhost-needs-its-scheme-spelled-out)
- [Firewall, and binding 443 as a non-root user](#firewall-and-binding-443-as-a-non-root-user)
- [Ordering against tailscaled](#ordering-against-tailscaled)
- [No persistence entry](#no-persistence-entry)
- [Why the category isn't named `caddy`](#why-the-category-isnt-named-caddy)
- [Imported by](#imported-by)
- [See also](#see-also)

## Category contents

The `nixos`-class files: `caddy/caddy.nix` and
`tailscale-services/serve.nix` (the latter added 2026-09-07 — raw TCP
forwarding only, not HTTPS termination; see below).

The services they front are one table, `homelab/_lib/cube-services.nix`
(loopback port, `svc:` name, derived FQDN and URL). `caddy.nix`'s
`mkTsService` builds each entry's TLS vhost and both bare-name redirects
from it, `serve.nix` forwards a `tcp:443`/`tcp:80` pair per entry, and
grafana.nix and forgejo.nix read their port and `root_url`/`ROOT_URL` from
it, so none of them can disagree with a vhost. A new entry also needs a line
in caddy.nix's `guards` (evaluation fails without one).

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

The root route answers 404: the landing page (homepage, and glance beside
it) was removed 2026-10-19 as unused attack surface. Their Service objects
(`svc:homepage`, `svc:glance`) and ACL entries are the control-plane half
this repo only records and still need `vip-delete` / removal by hand.

## Bare-name vhosts

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
  before the `http://` redirect gets a chance: such a browser sends TLS SNI
  = the literal string `git`, **not** the FQDN, even though the OS resolver
  completes the bare name for DNS purposes via `tailscale0`'s search domain
  — SNI is fixed before that completion is visible downstream. With no vhost
  matching that SNI, Caddy falls back to trying for a publicly-issued cert
  for `git`, which can never succeed (confirmed live: `curl -v https://git/`
  returned a raw `TLSv1.3 (IN), TLS alert, internal error (592)`). Short of trusting that CA on
  every client there is no improving them, and they were deliberately kept
  rather than dropped once `http://` worked.

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
`general-config/system/networking/tailscale.nix` — that file is in the `system` category
*every* Linux host imports, and setting it there would grant cert-fetching
rights to a `caddy` user on hosts that don't run Caddy. Scope a change to
the host that needs it.

## Fronting Tailscale Services with Caddy

MagicDNS's one-name-per-device limit is why both apps originally shared a
path prefix on `ts-cube`'s one hostname; Tailscale Services (`svc:`) lifted
that 2026-09-07, giving each its own tailnet DNS name with no prefix — see
[reverse-proxy-history.md](reverse-proxy-history.md#paths-not-subdomains-was-the-original-constraint--tailscale-services-lifted-it-partially)
for the original per-path mechanics and what Services did and didn't solve.
Caddy stays in the loop regardless, since Services can't terminate HTTPS
declaratively on this tailscale version.

`tailscale-services/serve.nix` configures each service's `endpoints` with
a `tcp://` backend scheme — raw byte forwarding, no HTTP interpretation —
pointed at Caddy's own loopback address, `127.0.0.1:443`. tailscaled
forwards the untouched TLS bytes (SNI ClientHello included) from each
service's virtual address; Caddy picks the right vhost by SNI, same
mechanism it already used to be the one thing on this host bound to 443,
now serving several names instead of one
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

Grafana and Forgejo wanted opposite `handle`/`handle_path` treatment for
the path prefix they used to share — retired 2026-09-07 along with the
prefix routes themselves, once each app got its own vhost with no prefix
left to disagree about. See
[reverse-proxy-history.md](reverse-proxy-history.md#the-two-apps-want-opposite-things-from-the-proxy-historical)
for the mechanism (which app needed which directive and why) and the
first-switch failure it caused.

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

The one other interface that reaches 443 is libvirt's `virbr0`, opened
for the Actions runner VM ([virtualization](virtualization.md)). Every
`.ts.net` vhost except `git.` carries `vmDeny` — a
`remote_ip 192.168.122.0/24` matcher in a `handle` that aborts — so a
guest sending another Host/SNI gets nothing. It is a `handle`, not a bare
`abort`, because `handle` sorts ahead of `abort` and the `ts-cube` vhost's
catch-all `handle` (the 404) would win otherwise (checked with `caddy adapt`,
2.11.4). The bare-name `https://` twins don't carry it: `redir` sorts
ahead of `handle` as well, so there it would never run, and all they give
a guest is a 301 to a name that does.

`git.` itself carries `vmRunnerPathsOnly` instead: guests reach only the
paths CI uses — `/api/actions/`, `/api/actions_pipeline/`, the v4 artifact
service under `/twirp/github.actions.results.api.v1.ArtifactService/`,
`/api/v1/`, and git over HTTPS (`<owner>/<repo>/info/refs`,
`git-upload-pack`, `git-receive-pack`, `info/lfs/`) — as a `not
path_regexp` inside a `remote_ip` matcher, handled with `abort`. The web UI,
login form included, is out of a job's reach. The path list comes from
Forgejo 15's `routers/init.go` and was checked against a local Caddy with
both allowed and refused paths.

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

A category and its one module both declaring `caddy` would both write
`flake.modules.nixos.caddy` and silently **merge** rather than error (the
`containers`/`podman.nix` collision [architecture.md](../architecture.md)
documents, hit for real twice in this tree already). [git-forge](git-forge.md)
and [shortlinks](shortlinks.md) are named for the same reason.

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
- [system](system.md) — `networking.nix` for the firewall rule this rests
  on, and `tailscale.nix` for the out-of-repo tailnet traps.
- [homelab/00-INDEX.md](../homelab/00-INDEX.md) — the usage side: the current
  URLs for everything on cube.
- [hosts.md](../hosts.md) — current switch/verification status for
  `nire-cube`.
- [reverse-proxy-history.md](reverse-proxy-history.md) — the second
  switch's full verification checklist.
