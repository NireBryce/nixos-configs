# Caddy: one tailnet-only HTTPS front door for every web service on this
# host. Added 2026-08-24, cube-only, own category (`nire/reverse-proxy/`) for
# the same "if something shared needs to be optional, a category is the
# mechanism" reason `monitoring`, `git-forge` and `shortlinks` each already
# give (CLAUDE.md's Architecture section) -- the handhelds have no web
# services to front, and durandal has not asked for one.
#
# The category is named `reverse-proxy`, not `caddy`: a category and its one
# module both named `caddy` would declare the same
# `flake.modules.nixos.caddy` attribute and silently MERGE rather than
# error. That's the `containers`/`podman.nix` collision CLAUDE.md documents,
# hit for real writing `git-forge` and again writing `shortlinks`.
#
# WHAT THIS CHANGED ELSEWHERE, in the same commit -- read those two files'
# own history notes, this is the summary:
#
#   - monitoring/grafana/grafana.nix  http_addr 0.0.0.0 -> 127.0.0.1
#   - git-forge/forgejo/forgejo.nix   HTTP_ADDR 0.0.0.0 -> 127.0.0.1
#
# Both used to listen on every interface and rely ENTIRELY on
# `trustedInterfaces = [ "tailscale0" ]` (system/networking/networking.nix)
# to keep the LAN out -- a firewall property, not a listener property, and
# one firewall mistake away from being on the LAN. They now listen on
# loopback only and are reachable exclusively through this proxy, so the
# firewall is no longer the only thing standing between them and the
# network. The old URLs stop working, deliberately:
#
#     http://ts-cube:3000/  ->  https://ts-cube.moose-micro.ts.net/grafana/
#     http://ts-cube:3001/  ->  https://ts-cube.moose-micro.ts.net/git/
#
# TAILSCALE ISSUES THE CERT, AND CADDY DOES IT WITH NO PLUGIN. Checked
# caddy 2.11.4's own source in the pinned nixpkgs rather than assuming a
# `withPlugins` build was needed: modules/caddyhttp/autohttps.go:884
# defines `isTailscaleDomain` as nothing more than a `.ts.net` suffix
# check, and any site address matching it is pulled OUT of the normal
# ACME-managed set and handed to `tls.get_certificate.tailscale`
# (modules/caddytls/certmanagers.go:28), which asks the LOCAL tailscaled
# for the cert. So: no ACME account, no `email`, no DNS-01 credentials, no
# xcaddy rebuild with a vendor hash. Ordinary `pkgs.caddy` and a `.ts.net`
# site address is the whole mechanism.
#
# `services.tailscale.permitCertUid = "caddy"` below is what makes that
# request succeed, and it is NOT optional. tailscaled refuses cert requests
# from non-root local-API clients unless the peer's uid matches
# TS_PERMIT_CERT_UID (ipn/ipnserver/server.go:390, `CanFetchCerts`, whose
# own upstream comment names caddy as the intended case). That option is
# set HERE rather than in system/networking/tailscale.nix on purpose:
# tailscale.nix is in the `system` category that EVERY Linux host imports,
# so setting it there would grant cert-fetching rights to a `caddy` user on
# durandal, tenacity and lego -- three hosts that don't run caddy at all.
# Scoped to the category that actually needs it, the same way
# `virtualization`'s VM fixes were scoped to the host that had the bug.
# The value is resolved by name at request time (`userIDFromString` does a
# `user.Lookup` when the value isn't all digits), so it tracks whatever uid
# services.caddy's own `caddy` user ends up with -- nothing to keep in sync.
#
# TAILNET HTTPS MUST BE ENABLED IN THE ADMIN CONSOLE, and this one was
# checked rather than assumed: `tailscale status --json` on nire-lysithea,
# 2026-08-24, reported a non-empty `CertDomains`, which is the tailnet-wide
# HTTPS-certificates setting being on. If it were off, every request here
# would fail the TLS handshake with nothing wrong in this file. It's a
# claim about the Tailscale admin console, same class as tailscale.nix's
# "TWO REAL TRAPS" -- not something this repo can assert.
#
# THE FQDN IS WRITTEN OUT, and it is `ts-cube`, NOT `nire-cube`. This
# tailnet renames its devices fleet-wide (tailscale.nix's trap #1, the
# expensive one). Verified against the live tailnet rather than inferred
# from that doc: `tailscale status --json` from lysithea, 2026-08-24, lists
# the peer as `ts-cube.moose-micro.ts.net.` and its own MagicDNSSuffix as
# `moose-micro.ts.net`. The same string appears in grafana.nix's `root_url`
# and forgejo.nix's `ROOT_URL`; there is no shared constant for it because
# nothing in this tree declares options (CLAUDE.md, Architecture), so a
# change here means editing those two as well.
#
# PATHS, NOT PORTS OR SUBDOMAINS, and that's forced. MagicDNS gives a
# device exactly ONE name, so `grafana.ts-cube...` does not resolve and
# cannot be made to without either Tailscale Services (`svc:`, which needs
# per-service admin approval) or a real domain with split DNS. Both apps
# are therefore mounted under a path prefix, which each has to be told
# about: grafana.nix sets `serve_from_sub_path` + `root_url`, forgejo.nix
# sets `ROOT_URL`.
#
# THE TWO APPS THEN WANT OPPOSITE THINGS FROM THE PROXY, which is the one
# thing here that was actually gotten wrong on the first live test
# (2026-08-24: /grafana/ returned 200, /git/ returned 404). Grafana, with
# `serve_from_sub_path`, serves UNDER the prefix and needs it left on, so
# it gets `handle`. Forgejo has no equivalent option, always serves at `/`,
# and needs the prefix STRIPPED, so it gets `handle_path` -- while its
# ROOT_URL keeps the `/git/` so the links it generates still point through
# the prefix. Full detail at each route below.
#
# NO FIREWALL CHANGE, on purpose. 443/80 are NOT added to
# `networking.firewall.allowedTCPPorts` -- the same reasoning grafana.nix
# and forgejo.nix each already spell out for their own ports:
# `trustedInterfaces = [ "tailscale0" ]` lets tailnet traffic bypass the
# allow-list, everything arriving on any other interface hits the
# default-deny. What's changed is that the firewall is now the SECOND line
# rather than the only one, since the apps behind it are on loopback.
# Caddy itself still binds every interface: it can't bind the tailnet IP
# specifically, because that address is assigned at runtime by tailscaled
# and isn't knowable at build time.
#
# Binding 443 as the unprivileged `caddy` user works because upstream's own
# caddy.service -- which nixpkgs ships via `systemd.packages` and only
# overrides ExecStart on -- carries
# `AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE`. Read out of the
# caddy dist tarball rather than assumed; nothing in this file needs to
# grant it.
#
# STATUS: RUNTIME-VERIFIED end to end on nire-cube, 2026-08-24. `just
# switch` came up with 0 failed units, `caddy.service` `active (running)`
# with `NRestarts=0`, and from ANOTHER tailnet host (lysithea, not
# localhost on cube):
#
#     https://ts-cube.moose-micro.ts.net/grafana/  ->  200, TLS verified
#     https://ts-cube.moose-micro.ts.net/git/      ->  200, TLS verified
#     https://ts-cube.moose-micro.ts.net/          ->  200 (the index below)
#     https://ts-cube.moose-micro.ts.net/git       ->  301 to /git/
#     http://ts-cube/                              ->  301 to the FQDN
#
# `tls_verify_result` was 0, i.e. the tailscaled-issued cert validated
# against the system trust store -- the whole point of this module, and
# not something evaluation or a build could have told us. Forgejo's
# generated links were checked too (`href="/git/explore/repos"`, and an
# asset under /git/ returning 200), because a stripped prefix can proxy
# correctly and still emit links that 404 on the next click. `ss -ltn` on
# the host confirms 3000/3001 bound to 127.0.0.1 only, with 80/443 the
# only tailnet-facing listeners.
#
# It took two switches. The first shipped `handle` for BOTH apps and
# Forgejo answered 404 to everything -- see the route comments below, and
# `claude cave/lessons-learned.md` #41. Everything static had passed:
# eval, `just modules`, `caddy adapt`, a real build, and reading the built
# artifact back. Only a live request found it.
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
                    # NAMED matchers, not inline ones. `handle` accepts at
                    # most ONE matcher token, so `handle /grafana /grafana/*`
                    # is a parse error ("wrong argument count or unexpected
                    # line ending") -- caught by running the generated
                    # Caddyfile through a real `caddy adapt` before this
                    # shipped, which is the only reason it isn't in the first
                    # `just switch`. The two-path form is deliberate over the
                    # shorter `/grafana*`: that also matches `/grafanafoo`.
                    @grafana path /grafana /grafana/*
                    handle @grafana {
                        reverse_proxy 127.0.0.1:3000
                    }

                    # Forgejo is `handle_path`, NOT `handle`, and that
                    # asymmetry with Grafana above is the whole point --
                    # getting it wrong is a 404, which is exactly how it was
                    # found (first live test, 2026-08-24: /grafana/ returned
                    # 200 and /git/ returned 404). The two apps want opposite
                    # things from a proxy:
                    #
                    #   - Grafana, with serve_from_sub_path = true, SERVES
                    #     under /grafana and wants the prefix left on.
                    #   - Forgejo has no such option. It always serves at
                    #     `/` -- confirmed on the host itself, not inferred:
                    #     `curl 127.0.0.1:3001/` is 200 and
                    #     `curl 127.0.0.1:3001/git/` is 404 -- and expects
                    #     the proxy to strip. Its ROOT_URL still carries
                    #     `/git/`, which is what makes the links it
                    #     GENERATES point back through this prefix. Same
                    #     shape as the nginx `proxy_pass http://…:3001/;`
                    #     trailing-slash idiom Gitea/Forgejo document.
                    #
                    # `handle_path /git/*` strips the `/git` prefix. It takes
                    # an inline path matcher only -- a named matcher is
                    # rejected -- so the bare `/git` (no trailing slash) can't
                    # ride along in the same matcher the way @grafana's two
                    # paths do, and gets its own redirect below instead.
                    @gitbare path /git
                    handle @gitbare {
                        redir https://${tailnetFqdn}/git/ permanent
                    }

                    handle_path /git/* {
                        reverse_proxy 127.0.0.1:3001
                    }

                    # Placeholder index. Two path matchers on one host is
                    # exactly the arrangement that makes "what else is on
                    # here?" unanswerable from a browser, and the answer is
                    # otherwise a 404 with no hint. If the `shortlinks`
                    # category's golink is up, `go/` is the better index;
                    # this is the fallback for when you're already here.
                    handle {
                        respond "nire-cube: /grafana  /git" 200
                    }
                '';

                # Bare MagicDNS name -> the real thing. `http://` in the site
                # address is load-bearing: it tells caddy this site is
                # HTTP-only and suppresses automatic HTTPS for it. Without
                # the scheme, caddy would try to obtain a cert for the name
                # `ts-cube`, which is not a `.ts.net` domain, so the
                # tailscale manager would decline it and it would fall
                # through to caddy's internal CA -- an untrusted cert on a
                # name that only ever needed to redirect.
                virtualHosts."http://ts-cube".extraConfig = ''
                    redir https://${tailnetFqdn}{uri} permanent
                '';
            };

            # See the header: without this, tailscaled refuses to hand caddy
            # a cert, and every HTTPS request fails at the handshake with
            # nothing visibly wrong here. Set in this module rather than in
            # system/networking/tailscale.nix so it reaches only hosts that
            # actually import this category.
            services.tailscale.permitCertUid = "caddy";

            # Certs (and caddy's own account state) live under
            # /var/lib/caddy, which the upstream module already declares as a
            # StateDirectory. No caddy-persist.nix alongside this, same
            # reasoning grafana.nix, forgejo.nix and golink.nix each give:
            # cube-configuration.nix's header says this host has a plain
            # persistent root, not the `/root` wipe durandal/tenacity/lego
            # get. If this module is ever imported by a host that DOES wipe
            # root, add one first, modeled on tailscale-persist.nix --
            # otherwise every boot re-fetches certs from tailscaled.
            systemd.services.caddy = {
                # Ordering only, not a dependency: tailscaled is enabled
                # unconditionally by system/networking/tailscale.nix on every
                # host that could import this, so there is nothing to pull
                # in. What this avoids is the narrow startup window where
                # caddy asks a not-yet-running tailscaled for a cert; the
                # tailscale cert manager is consulted per-handshake, so
                # getting this wrong would mean early requests failing and
                # later ones working -- an intermittent, easy-to-misread
                # failure rather than a clean one.
                after = [ "tailscaled.service" ];
            };
        };
}
