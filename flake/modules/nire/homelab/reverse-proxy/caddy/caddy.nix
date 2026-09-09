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
# only through this proxy at the time, so the firewall was no longer the
# only line. The old URLs stopped working, deliberately:
#
#     http://ts-cube:3000/  ->  https://ts-cube.moose-micro.ts.net/grafana/
#     http://ts-cube:3001/  ->  https://ts-cube.moose-micro.ts.net/git/
#
# BOTH MOVED AGAIN, off the shared `ts-cube` hostname onto their own
# Tailscale Services names (`svc:grafana`, `svc:git`) -- but Caddy is
# STILL the one terminating TLS for both, via the two vhosts below, not
# tailscaled: Tailscale Services cannot terminate HTTPS declaratively as
# of this tailscale version (confirmed upstream bug, see
# tailscale-services/serve.nix's history section for the full trail).
# `services.tailscale.serve` (serve.nix) does only raw TCP forwarding
# from each service's virtual address to Caddy's own loopback listener,
# unchanged in kind from what this proxy already did -- just reached via
# a different tailnet address per app instead of a path under one shared
# address. The `/grafana/`/`/git/` paths above are retired; this file's
# history section below keeps the mechanism that made them work, in case
# either move needs reverting.
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
# PATHS, NOT PORTS OR SUBDOMAINS, was the original constraint, and it's
# gone for Grafana/Forgejo specifically: MagicDNS gives a device ONE name,
# so a path prefix under `ts-cube...` was the only option without
# Tailscale Services -- reopened 2026-09-07
# (reverse-proxy/tailscale-services/), which is what moved both apps off
# this proxy's routes entirely. Anything added to THIS proxy in the
# future still has the same constraint, unless it also gets its own
# service name.
#
# THE TWO APPS WANTED OPPOSITE THINGS FROM THIS PROXY, back when both
# routed through it -- the one thing gotten wrong on the first live test
# (2026-08-24: /grafana/ 200, /git/ 404). Full mechanism moved to this
# file's history section below along with the routes themselves; still
# relevant if either app ever needs a path-prefix route added back here.
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
# host (lysithea), 2026-08-24, for the routes THIS FILE STILL HAS (glance
# at `/`, the bare-name redirect): 200 over validated TLS,
# `tls_verify_result` 0 -- the tailscaled-issued cert validated against
# the system trust store, which eval or a build could not have shown;
# `ss -ltn` confirmed 80/443 the only tailnet-facing listeners. The
# `/grafana/`/`/git/` verification this section used to describe covered
# routes that no longer exist here -- see the history section for what
# was checked and how it was gotten wrong once (`wiki/lessons-learned.md`
# #41) before reverse-proxy/tailscale-services/serve.nix replaced them,
# not yet independently verified.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);

        # See this file's header: verified against the live tailnet, and
        # duplicated (by necessity) in grafana.nix and forgejo.nix.
        tailnetFqdn = "ts-cube.moose-micro.ts.net";

        # The two Tailscale Services' own DNS names -- duplicated in
        # grafana.nix's root_url/domain and forgejo.nix's ROOT_URL, and in
        # tailscale-services/serve.nix's raw-forward targets, same
        # "nothing declares options" reasoning as tailnetFqdn above.
        # Reached over the tailnet via each service's own virtual
        # address, forwarded here at the TCP level -- Caddy itself only
        # ever sees loopback connections, same as the tailnetFqdn vhost.
        grafanaFqdn = "grafana.moose-micro.ts.net";
        gitFqdn     = "git.moose-micro.ts.net";

        # Added 2026-09-08, same shape as the two above: glance gets its
        # own Tailscale Service (`svc:glance`, serve.nix) instead of being
        # reached only via tailnetFqdn's `/` route -- see this file's
        # `glanceFqdn` vhost below and serve.nix's history note for why the
        # bare `http://glance` redirect needed it (the name didn't resolve
        # at all without a real Service behind it).
        glanceFqdn  = "glance.moose-micro.ts.net";
    in {
        flake.modules.nixos.${moduleName} = {
            # # description = "caddy -- tailnet-only HTTPS front door, with certs from tailscaled";

            services.caddy = {
                enable = true;

                # One set, not four separate `virtualHosts.X.extraConfig =`
                # assignments -- statix (`just lint`) flags repeated
                # top-level-key assignments as the same footgun that made
                # `caddy`-the-category and `caddy`-the-module MERGE instead
                # of erroring (this file's own header); harmless here since
                # each key differs, but the ratchet doesn't know that.
                virtualHosts = {
                    # The attribute name IS the site address (caddy's
                    # vhost-options.nix defaults `hostName` to it), and a
                    # bare `.ts.net` address is what triggers the tailscale
                    # cert manager -- see the header.
                    ${tailnetFqdn}.extraConfig = ''
                        # Grafana and Forgejo moved OFF this proxy to their
                        # own Tailscale Services names (`svc:grafana`,
                        # `svc:git`) -- see the two vhosts below and
                        # reverse-proxy/tailscale-services/serve.nix. The
                        # `@grafana`/`handle_path /git/*` routes that used
                        # to live here, including the named-vs-inline-
                        # matcher asymmetry between the two apps, are
                        # `git log`'s to find if this ever needs
                        # reverting -- wiki/lessons-learned.md #41 still has
                        # the mechanism written up in full.
                        #
                        # Everything not claimed above goes to glance
                        # (nire/landing/), the service index -- what's
                        # running, whether it's up, how this machine is
                        # doing. Replaced a plaintext `respond` placeholder
                        # here 2026-08-24, the day it was written.
                        #
                        # The one route with no prefix question: glance
                        # serves at `/`, nothing stripped or preserved. Its
                        # assets (/static/..., /api/...) fall through here
                        # too -- not under a prefix either.
                        handle {
                            reverse_proxy 127.0.0.1:3002
                        }
                    '';

                    # Grafana and Forgejo's own vhosts. Same
                    # `isTailscaleDomain` cert mechanism as `tailnetFqdn`
                    # above -- these connections arrive over loopback
                    # (tailscaled's raw TCP forward from each service's
                    # virtual address, serve.nix), but Caddy asks
                    # tailscaled for the cert using the SITE ADDRESS
                    # (`grafana.moose-micro.ts.net`), not the connecting
                    # address, so it doesn't matter that the socket peer is
                    # 127.0.0.1 -- confirmed against caddytls/
                    # certmanagers.go the same way tailnetFqdn's mechanism
                    # was (see header).
                    #
                    # No path matcher needed, unlike the retired
                    # /grafana//git/ routes -- each app gets its own vhost,
                    # so it serves at plain `/`, matching what
                    # serve_from_sub_path=false (grafana.nix) and the
                    # unprefixed ROOT_URL (forgejo.nix) now expect.
                    ${grafanaFqdn}.extraConfig = ''
                        reverse_proxy 127.0.0.1:3000
                    '';

                    ${gitFqdn}.extraConfig = ''
                        reverse_proxy 127.0.0.1:3001
                    '';

                    # Added 2026-09-08. Same mechanism as the two vhosts
                    # above: reached over loopback via serve.nix's raw TCP
                    # forward, tailscale issues the cert for the SITE
                    # ADDRESS regardless of the connecting address.
                    ${glanceFqdn}.extraConfig = ''
                        reverse_proxy 127.0.0.1:3002
                    '';

                    # Bare MagicDNS name -> the real thing. `http://` is
                    # load-bearing: it marks the site HTTP-only and
                    # suppresses automatic HTTPS. Without the scheme, caddy
                    # would seek a cert for `ts-cube`, which is not a
                    # `.ts.net` domain, so the tailscale manager would
                    # decline it and it would fall through to caddy's
                    # internal CA -- an untrusted cert on a name that only
                    # needed to redirect.
                    "http://ts-cube".extraConfig = ''
                        redir https://${tailnetFqdn}{uri} permanent
                    '';

                    # Short bare names for Tailscale Services, same redirect pattern
                    "http://git".extraConfig = ''
                        redir https://${gitFqdn}{uri} permanent
                    '';

                    "http://grafana".extraConfig = ''
                        redir https://${grafanaFqdn}{uri} permanent
                    '';

                    # Landing/glance index -- now its own Service (see
                    # glanceFqdn above), not tailnetFqdn; ts-cube's `/`
                    # still works directly, this is just the short name.
                    "http://glance".extraConfig = ''
                        redir https://${glanceFqdn}{uri} permanent
                    '';

                    # HTTPS twins of the three bare-name redirects above.
                    # Added 2026-09-08, the day the HTTP-only versions
                    # turned out to be half the fix.
                    #
                    # A browser hitting `https://git` (no scheme typed,
                    # HTTPS-first browser behaviour, or just a bookmark)
                    # sends TLS SNI = the literal string "git" -- NOT
                    # "git.moose-micro.ts.net", even though the OS resolver
                    # silently completes the bare name to the FQDN for DNS
                    # purposes via tailscale0's search domain. SNI is fixed
                    # by the browser before that completion is visible to
                    # anything downstream. Caddy had no vhost matching that
                    # SNI (only the HTTP-only ones above, plus the three
                    # FQDN vhosts), so it fell to its default automatic-
                    # HTTPS behaviour: try to get a publicly-issued cert for
                    # "git", which cannot ever succeed (not a real
                    # ACME-validatable domain) -- confirmed live,
                    # `curl -v https://git/` returned a raw
                    # `TLSv1.3 (IN), TLS alert, internal error (592)`,
                    # Firefox's SSL_ERROR_INTERNAL_ERROR_ALERT.
                    #
                    # `tls internal` forces Caddy's own local CA instead of
                    # its default (ACME) issuer for JUST these three site
                    # addresses -- scoped per-vhost, does not touch
                    # automatic_https globally or the tailscale cert
                    # manager the FQDN vhosts above still use (that's keyed
                    # off the `.ts.net`-suffixed site address, unaffected
                    # by what any other vhost does). Trades the previous
                    # unrecoverable TLS handshake failure for a normal
                    # untrusted-cert warning a browser lets you click
                    # through -- exactly what the tailnetFqdn header
                    # predicted would happen for `ts-cube` if it dropped
                    # its own `http://` scheme; same mechanism, applied here
                    # on purpose instead of avoided. `ts-cube` itself still
                    # has the same underlying gap (no `https://ts-cube`
                    # vhost) -- not touched here, nobody's hit it in
                    # practice; same fix if it ever comes up.
                    "https://git".extraConfig = ''
                        tls internal
                        redir https://${gitFqdn}{uri} permanent
                    '';

                    "https://grafana".extraConfig = ''
                        tls internal
                        redir https://${grafanaFqdn}{uri} permanent
                    '';

                    "https://glance".extraConfig = ''
                        tls internal
                        redir https://${glanceFqdn}{uri} permanent
                    '';
                };
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

# ── history ─────────────────────────────────────────────────────────────────
#
# 2026-08-24 to 2026-09-07 — Grafana and Forgejo routed through here as
# `/grafana/` and `/git/` path prefixes, retired by
# reverse-proxy/tailscale-services/serve.nix (svc:grafana/svc:git, each
# with its own tailnet name). Kept here in full since path-prefix routing
# under one shared hostname is the fallback if that move doesn't hold up.
#
# THE TWO APPS WANTED OPPOSITE THINGS FROM THE PROXY, and getting it wrong
# cost the first live switch (2026-08-24: /grafana/ 200, /git/ 404,
# `wiki/lessons-learned.md` #41's general case):
#
#   - Grafana, with `serve_from_sub_path = true`, SERVED UNDER the prefix
#     and needed it left ON: `handle`.
#   - Forgejo had no equivalent option and always served at `/` --
#     confirmed on the host (`curl 127.0.0.1:3001/` 200, `curl
#     127.0.0.1:3001/git/` 404) -- so the proxy had to STRIP the prefix:
#     `handle_path`. Its `ROOT_URL` kept `/git/` anyway, which is what
#     made its GENERATED links point back through the prefix -- same
#     shape as nginx's `proxy_pass http://…:3001/;` trailing-slash idiom.
#
# The actual routes:
#
#     @grafana path /grafana /grafana/*
#     handle @grafana {
#         reverse_proxy 127.0.0.1:3000
#     }
#
#     @gitbare path /git
#     handle @gitbare {
#         redir https://${tailnetFqdn}/git/ permanent
#     }
#     handle_path /git/* {
#         reverse_proxy 127.0.0.1:3001
#     }
#
# NAMED matchers, not inline, for `@grafana`: `handle` accepts at most ONE
# matcher token, so `handle /grafana /grafana/*` is a parse error ("wrong
# argument count or unexpected line ending") -- caught by running the
# generated Caddyfile through `caddy adapt` before shipping. The two-path
# form was deliberate over `/grafana*`, which would also match
# `/grafanafoo`. `handle_path` for Forgejo took an INLINE path matcher
# only -- a named matcher was rejected -- so the bare `/git` couldn't ride
# along the way `@grafana`'s two paths did, hence its own separate
# redirect block above.
#
# RUNTIME-VERIFIED end to end on nire-cube from another tailnet host
# (lysithea), 2026-08-24: 200 over validated TLS on /grafana/, /git/ and /
# (glance); Forgejo's generated links specifically checked, since a
# stripped prefix can proxy correctly yet still emit links that 404 on
# the next click. Took two switches to get right -- eval, `just modules`,
# `caddy adapt`, a real build, and reading the artifact back all passed
# on the first; only a live request found the `handle`/`handle_path`
# asymmetry.
