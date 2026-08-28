# Caddy: one tailnet-only HTTPS front door for every web service on this
# host. Added 2026-08-24, cube-only, own category (`nire/reverse-proxy/`)
# for the same "if something shared needs to be optional, a category is
# the mechanism" reason `monitoring`, `git-forge` and `shortlinks` each
# give (CLAUDE.md's Architecture section) -- the handhelds have no web
# services, durandal has not asked.
#
# The category is named `reverse-proxy`, not `caddy`: a category and its
# one module both named `caddy` would declare the same
# `flake.modules.nixos.caddy` attribute and silently MERGE rather than
# error -- the `containers`/`podman.nix` collision CLAUDE.md documents,
# hit for real writing `git-forge` and again `shortlinks`.
#
# WHAT THIS CHANGED ELSEWHERE, same commit (see those files' history
# notes): grafana.nix `http_addr` and forgejo.nix `HTTP_ADDR`, both
# 0.0.0.0 -> 127.0.0.1. Both relied ENTIRELY on
# `trustedInterfaces = [ "tailscale0" ]` (system/networking/networking.nix)
# to keep the LAN out -- a firewall property, not a listener property, one
# firewall mistake from being on the LAN. Loopback-only now, reachable
# only through this proxy, so the firewall is no longer the only line.
# The old URLs stop working, deliberately:
#
#     http://ts-cube:3000/  ->  https://ts-cube.moose-micro.ts.net/grafana/
#     http://ts-cube:3001/  ->  https://ts-cube.moose-micro.ts.net/git/
#
# TAILSCALE ISSUES THE CERT, NO PLUGIN NEEDED -- checked in caddy 2.11.4's
# source (pinned nixpkgs), not assumed: modules/caddyhttp/autohttps.go:884
# defines `isTailscaleDomain` as a `.ts.net` suffix check; a matching site
# address is pulled from the normal ACME set and handed to
# `tls.get_certificate.tailscale` (modules/caddytls/certmanagers.go:28),
# which asks the LOCAL tailscaled. No ACME account, `email`, DNS-01
# credentials, or xcaddy rebuild -- ordinary `pkgs.caddy` and a `.ts.net`
# site address is the whole mechanism.
#
# `services.tailscale.permitCertUid = "caddy"` below is what makes that
# request succeed, NOT optional: tailscaled refuses cert requests from
# non-root local-API clients unless the peer's uid matches
# TS_PERMIT_CERT_UID (ipn/ipnserver/server.go:390, `CanFetchCerts`, whose
# upstream comment names caddy as the intended case). Set HERE, not in
# system/networking/tailscale.nix: tailscale.nix is in the `system`
# category every Linux host imports, so it would grant a `caddy` user
# cert rights on durandal and tenacity, which don't run caddy -- scoped
# to the category that needs it, like `virtualization`'s VM fixes.
# Resolved by name at request time (`userIDFromString` does a
# `user.Lookup` for a non-numeric value), tracking whatever uid caddy's
# user gets -- nothing to keep in sync.
#
# TAILNET HTTPS MUST BE ON IN THE ADMIN CONSOLE, checked not assumed:
# `tailscale status --json` on nire-lysithea, 2026-08-24, reported a
# non-empty `CertDomains` (the tailnet-wide HTTPS-certificates setting).
# If it were off, every request fails the TLS handshake with nothing
# wrong in this file -- an admin-console claim, like tailscale.nix's
# "TWO REAL TRAPS", not assertable from this repo.
#
# THE FQDN IS `ts-cube`, NOT `nire-cube` -- this tailnet renames devices
# fleet-wide (tailscale.nix's trap #1, the expensive one), verified live
# 2026-08-24 (`tailscale status --json` from lysithea: peer
# `ts-cube.moose-micro.ts.net.`, MagicDNSSuffix `moose-micro.ts.net`).
# Same string in grafana.nix's `root_url` and forgejo.nix's `ROOT_URL`;
# no shared constant, nothing here declares options (CLAUDE.md,
# Architecture) -- a change means editing those two.
#
# PATHS, NOT PORTS OR SUBDOMAINS, and that's forced: MagicDNS gives a
# device ONE name, so `grafana.ts-cube...` does not resolve and can't be
# made to without Tailscale Services (`svc:`, per-service admin approval)
# or a real domain with split DNS. Both apps mount under a path prefix,
# each told about it: grafana.nix sets `serve_from_sub_path` +
# `root_url`, forgejo.nix sets `ROOT_URL`.
#
# THE TWO APPS WANT OPPOSITE THINGS FROM THE PROXY -- the one thing
# gotten wrong on the first live test (2026-08-24: /grafana/ 200, /git/
# 404). Grafana, with `serve_from_sub_path`, serves UNDER the prefix and
# needs it left on: `handle`. Forgejo has no equivalent, always serves at
# `/`, needs the prefix STRIPPED: `handle_path`, while ROOT_URL keeps
# `/git/` so its generated links still point through the prefix. Detail
# at each route below.
#
# NO FIREWALL CHANGE, on purpose: 443/80 are NOT added to
# `networking.firewall.allowedTCPPorts`, same reasoning grafana.nix and
# forgejo.nix give for their own ports -- `trustedInterfaces` lets
# tailnet traffic bypass the allow-list, everything else hits
# default-deny. What's changed: the firewall is now the SECOND line, the
# apps being on loopback. Caddy still binds every interface: the tailnet
# IP is assigned at runtime by tailscaled, unknowable at build time.
#
# Binding 443 as the unprivileged `caddy` user works because upstream's
# caddy.service -- shipped via `systemd.packages`, only ExecStart
# overridden -- carries `AmbientCapabilities=CAP_NET_ADMIN
# CAP_NET_BIND_SERVICE` (read from the dist tarball, not assumed).
#
# STATUS: RUNTIME-VERIFIED end to end on nire-cube from ANOTHER tailnet
# host (lysithea), 2026-08-24: 200 over validated TLS on /grafana/, /git/
# and / (the index route, proxying to glance, nire/landing/), plus both
# 301 redirects; `tls_verify_result` 0 -- the tailscaled-issued cert
# validated against the system trust store, which eval or a build could
# not have shown. Forgejo's generated links checked (a stripped prefix
# can proxy right yet emit links that 404 on the next click); `ss -ltn`:
# 3000/3001 on 127.0.0.1 only, 80/443 the only tailnet-facing listeners.
#
# Took two switches: the first shipped `handle` for both apps and
# Forgejo 404'd everything -- see the route comments and
# `claude cave/lessons-learned.md` #41; eval, `just modules`, `caddy
# adapt`, a real build, and reading the artifact back all passed. Only a
# live request found it.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);

        # See this file's header: verified against the live tailnet, and
        # duplicated (by necessity) in grafana.nix and forgejo.nix.
        tailnetFqdn = "ts-cube.moose-micro.ts.net";
    in {
        flake.modules.nixos.${moduleName} = {
            # # description = "caddy -- tailnet-only HTTPS front door, with certs from tailscaled";

            services.caddy = {
                enable = true;

                # The attribute name IS the site address (caddy's
                # vhost-options.nix defaults `hostName` to it), and a bare
                # `.ts.net` address is what triggers the tailscale cert
                # manager -- see the header.
                virtualHosts.${tailnetFqdn}.extraConfig = ''
                    # NAMED matchers, not inline: `handle` accepts at most
                    # ONE matcher token, so `handle /grafana /grafana/*` is
                    # a parse error ("wrong argument count or unexpected
                    # line ending") -- caught by running the generated
                    # Caddyfile through `caddy adapt` before shipping. The
                    # two-path form is deliberate over `/grafana*`: that
                    # also matches `/grafanafoo`.
                    @grafana path /grafana /grafana/*
                    handle @grafana {
                        reverse_proxy 127.0.0.1:3000
                    }

                    # Forgejo is `handle_path`, NOT `handle` -- the
                    # asymmetry with Grafana above is the whole point, and
                    # getting it wrong is a 404, exactly how it was found
                    # (first live test, 2026-08-24). Opposite things:
                    #
                    #   - Grafana, with serve_from_sub_path = true, SERVES
                    #     under /grafana and wants the prefix left on.
                    #   - Forgejo has no such option and always serves at
                    #     `/` -- confirmed on the host (`curl
                    #     127.0.0.1:3001/` 200, `curl
                    #     127.0.0.1:3001/git/` 404) -- and expects the
                    #     proxy to strip. ROOT_URL keeps `/git/`, which is
                    #     what makes its GENERATED links point back through
                    #     the prefix. Same shape as nginx's `proxy_pass
                    #     http://…:3001/;` trailing-slash idiom.
                    #
                    # `handle_path /git/*` strips the `/git` prefix. It
                    # takes an inline path matcher only -- a named matcher
                    # is rejected -- so the bare `/git` can't ride along
                    # the way @grafana's two paths do; its own redirect
                    # below.
                    @gitbare path /git
                    handle @gitbare {
                        redir https://${tailnetFqdn}/git/ permanent
                    }

                    handle_path /git/* {
                        reverse_proxy 127.0.0.1:3001
                    }

                    # Everything not claimed above goes to glance
                    # (nire/landing/), the service index -- what's
                    # running, whether it's up, how this machine is doing.
                    # Replaced a plaintext `respond` placeholder here
                    # 2026-08-24, the day it was written.
                    #
                    # The one route with no prefix question: glance serves
                    # at `/`, nothing stripped or preserved. Its assets
                    # (/static/..., /api/...) fall through here too --
                    # not under a prefix either.
                    handle {
                        reverse_proxy 127.0.0.1:3002
                    }
                '';

                # Bare MagicDNS name -> the real thing. `http://` is
                # load-bearing: it marks the site HTTP-only and suppresses
                # automatic HTTPS. Without the scheme, caddy would seek a
                # cert for `ts-cube`, which is not a `.ts.net` domain, so
                # the tailscale manager would decline it and it would fall
                # through to caddy's internal CA -- an untrusted cert on a
                # name that only needed to redirect.
                virtualHosts."http://ts-cube".extraConfig = ''
                    redir https://${tailnetFqdn}{uri} permanent
                '';
            };

            # See the header: without this, tailscaled refuses to hand
            # caddy a cert and every HTTPS request fails at the handshake
            # with nothing visibly wrong here. Set in this module, not in
            # system/networking/tailscale.nix, so it reaches only hosts
            # that import this category.
            services.tailscale.permitCertUid = "caddy";

            # Certs (and caddy's account state) live under /var/lib/caddy,
            # which the upstream module already declares as a
            # StateDirectory. No caddy-persist.nix, same reasoning as
            # grafana.nix/forgejo.nix/golink.nix: cube-configuration.nix's
            # header says this host has a plain persistent root, not the
            # `/root` wipe durandal/tenacity get. If a root-wiping host
            # ever imports this module, add one first, modeled on
            # tailscale-persist.nix -- else every boot re-fetches certs.
            systemd.services.caddy = {
                # Ordering only, not a dependency: tailscaled is enabled
                # unconditionally by system/networking/tailscale.nix on
                # every host that could import this. This avoids the
                # narrow startup window where caddy asks a not-yet-running
                # tailscaled for a cert; the cert manager is consulted
                # per-handshake, so getting it wrong means early requests
                # failing and later ones working -- intermittent and easy
                # to misread, rather than a clean failure.
                after = [ "tailscaled.service" ];
            };
        };
}
