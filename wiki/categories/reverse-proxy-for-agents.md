# `reverse-proxy`, for agents

_Last modified: 2026-09-14_

Condensed from [reverse-proxy.md](reverse-proxy.md), which keeps the
reasoning, the verification narrative and the links out. Facts only here.

Caddy, one tailnet-only HTTPS front door on `nire-cube`. Added 2026-08-24,
nested under `homelab` 2026-08-27.

## Files

`system/homelab/reverse-proxy/`, both `nixos`-class:

- `caddy/caddy.nix` — the Caddyfile, `permitCertUid`, systemd ordering.
- `tailscale-services/serve.nix` — `svc:` endpoints. Raw TCP forwarding
  only, never HTTPS termination. Added 2026-09-07.

## Current names

| Name | Backend | Shape |
|---|---|---|
| `https://grafana.moose-micro.ts.net/` | `127.0.0.1:3000` | own `svc:`, no path prefix |
| `https://git.moose-micro.ts.net/` | `127.0.0.1:3001` | own `svc:`, no path prefix |
| `https://homepage.moose-micro.ts.net/` | homepage | own `svc:`; glance's `svc:glance` renamed by #291, 2026-09-12 (object re-made at switch time) |
| `https://ts-cube.moose-micro.ts.net/` | homepage at `/` | device name, not a `svc:` |

Path-prefix routes are retired (2026-09-07) and 404. `http://<bare name>`
redirects; `https://<bare name>` serves Caddy's local CA and shows
`SEC_ERROR_UNKNOWN_ISSUER` by design — don't "fix" it.

## Rules

- **Every `.ts.net` vhost needs `get_certificate tailscale` named
  explicitly.** Any explicit `automation.policies` entry anywhere in the
  Caddyfile (a `tls internal` bare-name vhost is enough) suppresses Caddy's
  automatic `isTailscaleDomain` detection and points every `.ts.net` name at
  Let's Encrypt, which can never issue for a tailnet name. Symptom:
  `SSL_ERROR_INTERNAL_ERROR_ALERT` on names no commit touched.
- **`services.tailscale.permitCertUid = "caddy"` stays in `caddy.nix`**, not
  in `system/networking/tailscale.nix` — that file is imported by every
  Linux host.
- **`handle` takes at most one matcher token.** Two paths need a named
  matcher (`@name path /x /x/*`), not `handle /x /x/*`.
- **`handle_path` rejects a named matcher** — inline path matcher only.
- **Bare-name vhosts must spell out `http://`**, or Caddy tries to certify a
  non-`.ts.net` name and falls through to its internal CA.
- **A `https://<bare name>` request carries SNI = the literal bare name**,
  not the FQDN the resolver completes it to. Without a vhost matching that
  SNI, Caddy tries for a public cert on an unissuable name and the handshake
  dies (`TLS alert, internal error (592)`); the `tls internal` twins exist
  for exactly that.
- **A new `svc:` port needs declaring twice** — in the Service object and in
  `serve.nix`. `tcp:443` alone means `http://<name>` never answers.
- **Creating a `svc:` needs `systemctl restart tailscaled`, then
  `tailscale-serve`.** Re-running `serve set-config` against a standing
  advertisement does not activate a newly-created Service.
- **`vip-get` wants the `svc:` prefix** — without it every service 404s.
- No firewall ports. `trustedInterfaces = [ "tailscale0" ]` (from `system`)
  is what lets tailnet traffic in; 443 binds unprivileged via upstream
  `caddy.service`'s `AmbientCapabilities`.
- No `environment.persistence` entry — cube has a persistent root. A host
  that wipes `/root` would need one for `/var/lib/caddy` first.
- `landing` is a hard dependency: the root route proxies to the landing
  page (homepage since #291, port 3002 unchanged), so dropping `landing`
  leaves `/` at 502.

## Out-of-repo prerequisites

- HTTPS certificates enabled for the tailnet in Tailscale's admin console.
  Check with `tailscale status --json` → non-empty `CertDomains`.
- Service objects, ACL tags and autoApprovers are API-managed, not in Nix.
  `just tailscale-acl diff` is the reconciliation check.

## Known issues

- **#267 — fixed 2026-09-11, closed.** `tailscale-serve.service` is a
  `oneshot` that lost the boot race against tailscaled's backend state
  (`unexpected state: NoState`) and, with no `Restart=`, stayed failed 9.5
  hours on 2026-09-09. `serve.nix` now sets `Restart=on-failure` +
  `StartLimitIntervalSec`/`StartLimitBurst` — legal on `oneshot`, only
  `always`/`on-success` are rejected. Not yet seen recovering on a real
  boot.
- Tailscale Services cannot terminate HTTPS declaratively on this version —
  upstream bugs, not a config mistake. Caddy stays in the loop.

## Imported by

`nire-cube` only. Confirmed not to move durandal, tenacity or lysithea.

## See also

[reverse-proxy.md](reverse-proxy.md) · [monitoring.md](monitoring.md) ·
[git-forge.md](git-forge.md) · [shortlinks.md](shortlinks.md) ·
[system.md](system.md) ·
[reverse-proxy-history.md](reverse-proxy-history.md)
