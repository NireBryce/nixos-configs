# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki

# Caddy: one tailnet-only HTTPS front door for every web service on
# nire-cube. Added 2026-08-24, cube-only. The category is `reverse-proxy`,
# not `caddy`: a category and its one module sharing a name silently MERGE
# rather than error (CLAUDE.md, Architecture).
#
# Kept in the wiki, not restated here: the design and what it moved, the
# out-of-repo prerequisites (tailnet HTTPS in the admin console, each `svc:`
# object and its ACL entries) and the verification record --
# wiki/categories/reverse-proxy.md and its `-for-agents.md`;
# wiki/homelab/reaching-services.md for the URL map and what to do when
# something doesn't answer; `reverse-proxy-history.md` for the retired
# path-prefix routes. Traps sit next to the options they concern, below.
let
    # libvirt's default network (_lib/libvirt-net.nix)
    net = import ../../_lib/libvirt-net.nix;

    # Ports, names and FQDNs (`ts-cube`, NOT `nire-cube`, among them)
    # live in _lib/cube-services.nix, shared with grafana.nix,
    # forgejo.nix and serve.nix so none of them can disagree with a
    # vhost here.
    cube = import ../../_lib/cube-services.nix;

    tailnetFqdn = cube.deviceFqdn;

    # EVERY `.ts.net` vhost below MUST carry this. An explicit `tls`
    # directive ANYWHERE in this file makes the Caddyfile adapter emit an
    # automation policy covering every OTHER site too, and caddy's
    # tailscale-cert auto-detection only fires for names with NO policy
    # (2.11.4, read not assumed: autohttps.go:295 skips the
    # `isTailscaleDomain` branch at :328; the issuer-less policy then
    # falls back to public ACME, automation.go:238), which can never
    # issue for a tailnet name. That is how the `tls internal` vhosts
    # below took ALL tailnet HTTPS on this host down 2026-09-08 ->
    # 2026-09-10 -- `ts-cube` included, which no commit had touched --
    # while eval, build, `just modules` and `caddy adapt` all passed on a
    # Caddyfile that was VALID and meant something else
    # (wiki/lessons-learned.md §47). Naming the manager also beats the
    # detection it replaces: `implicitTailscaleManagersOnly()`
    # (automation.go:434) drops the public-CA fallback for an
    # all-`.ts.net` policy, so a name tailscaled won't issue for fails
    # closed instead of hammering Let's Encrypt.
    tailscaleCert = ''
        tls {
            get_certificate tailscale
        }
    '';
    # Every `.ts.net` vhost EXCEPT git's carries this. Caddy binds all
    # interfaces, and vm-networking.nix lets libvirt guests (the
    # Actions runner VM) reach 443 on the virbr0 gateway so they can
    # reach the forge -- with a Host/SNI of their choosing. The guest
    # subnet is libvirt's default network's. `handle`, not a bare
    # `abort @vm`: Caddyfile directive order puts `handle` ahead of
    # `abort`, so the landing vhost's own catch-all `handle` would win
    # over a bare abort; a matcher-carrying `handle` sorts ahead of the
    # matcherless one. Tailnet traffic arrives from loopback
    # (serve.nix) or tailscale0 addresses, never this range. NOT on
    # the bare-name `https://` twins below: `redir` sorts ahead of
    # `handle` too, so it would never run there -- and those only
    # redirect to a `.ts.net` name that does carry it (a guest gets
    # the 301, then nothing; verified from the runner guest
    # 2026-09-25).
    # The git vhost's version of `vmDeny`: guests (the runner VM) get
    # only what CI needs -- the runner protocol (/api/actions/), artifact
    # uploads (/api/actions_pipeline/, and the v4 twirp service), git
    # over HTTPS for any repo (info/refs, upload-pack, receive-pack,
    # LFS), and the REST API, which jobs call with their job token. Not
    # the web UI -- so no login form. Path list read from Forgejo 15's
    # routers/init.go; `[^/]+/[^/]+` also matches `repo.git`.
    vmRunnerPathsOnly = ''
        @vmNotRunnerPath {
            remote_ip ${net.cidr}
            not path_regexp ^/(api/actions/|api/actions_pipeline/|twirp/github\.actions\.results\.api\.v1\.ArtifactService/|api/v1/|[^/]+/[^/]+/(info/refs|git-upload-pack|git-receive-pack|info/lfs/))
        }
        handle @vmNotRunnerPath {
            abort
        }
    '';
    vmDeny = ''
        @vm remote_ip ${net.cidr}
        handle @vm {
            abort
        }
    '';

    # Which guard each service in the table gets. A service with no entry
    # here fails evaluation (attribute missing) rather than being proxied
    # unguarded.
    guards = {
        grafana = vmDeny;
        git     = vmRunnerPathsOnly;
    };

    # THE REFERENCE FOR ADDING A SERVICE (skill new-tailscale-service):
    # everything Caddy needs for one entry of _lib/cube-services.nix --
    # its TLS vhost and both bare-name redirects -- so a new service is
    # a table entry plus a `guards` line above, not a hand-copied trio.
    #
    # Each app has its own Tailscale Service name. It is reached over the
    # tailnet via that Service's virtual address and forwarded here as
    # raw TCP, so caddy only ever sees loopback connections -- it asks
    # tailscaled for the cert by SITE address, not by peer address, which
    # is why that works. Renaming an entry does NOT rename the
    # control-plane `svc:` object.
    mkTsService = svc: {
        # One vhost per app, so each serves at plain `/` and needs no
        # path matcher -- matching what serve_from_sub_path=false
        # (grafana.nix) and the unprefixed ROOT_URL (forgejo.nix) expect.
        ${svc.fqdn}.extraConfig = ''
            ${tailscaleCert}
            ${guards.${svc.name}}
            reverse_proxy 127.0.0.1:${toString svc.port}
        '';

        # `http://` is load-bearing on every bare-name vhost: it marks the
        # site HTTP-only and suppresses automatic HTTPS. Without the
        # scheme caddy would seek a cert for a non-`.ts.net` name, the
        # tailscale manager would decline, and it would fall through to
        # caddy's internal CA -- an untrusted cert on a name that only
        # redirects.
        #
        # UNLIKE `http://ts-cube`, the `svc:` bare names work only because
        # serve.nix forwards `tcp:80` here: `ts-cube` is a device address
        # where caddy binds 80 itself, a `svc:` name is a VIP answering
        # only on ports its Service object AND serve.nix both declare.
        # These sat unreachable from f478494a to 2026-09-11 (issue #272)
        # for that reason -- dead config that looked fine. Deleting a
        # `tcp:80` endpoint, in either half, silently returns them to it.
        #
        # These are the nice door: no certificate is involved, so they
        # land on the real tailnet cert rather than the local-CA warning
        # their `https://` twins below give.
        "http://${svc.name}".extraConfig = ''
            redir https://${svc.fqdn}{uri} permanent
        '';

        # HTTPS twin, for browsers that force HTTPS before the redirect
        # above gets a chance: they send TLS SNI = the literal bare name,
        # which no other vhost here matches. `tls internal` answers with
        # caddy's local CA, trading an unrecoverable handshake failure for
        # a click-through warning (SEC_ERROR_UNKNOWN_ISSUER) -- by design,
        # not a bug to fix. This is also a `tls` directive, which is what
        # makes `tailscaleCert` mandatory above; adding another one
        # anywhere carries the same obligation.
        "https://${svc.name}".extraConfig = ''
            tls internal
            redir https://${svc.fqdn}{uri} permanent
        '';
    };
in {
    nixos = { lib, ... }: {
        # # description = "caddy -- tailnet-only HTTPS front door, with certs from tailscaled";

        services.caddy = {
            enable = true;

            # One set, not an assignment per vhost -- statix (`just
            # lint`) flags repeated top-level-key assignments.
            #
            # The attribute name IS the site address (caddy's
            # vhost-options.nix defaults `hostName` to it), and a bare
            # `.ts.net` address is what makes the tailscale cert
            # manager eligible at all.
            virtualHosts = {
                # No landing page: the bare host answers 404.
                ${tailnetFqdn}.extraConfig = ''
                    ${tailscaleCert}
                    ${vmDeny}
                    handle {
                        respond "not found" 404
                    }
                '';

                # The device's own short name; see mkTsService for why the
                # scheme matters.
                "http://${cube.device}".extraConfig = ''
                    redir https://${tailnetFqdn}{uri} permanent
                '';

                # `ts-cube` has no `https://ts-cube` vhost (the gap
                # mkTsService's HTTPS twins close for the `svc:` names)
                # and is deliberately left alone -- nobody has hit it;
                # same fix if they do.
            }
            # Grafana and Forgejo (and any later entry in the table).
            // lib.mergeAttrsList (map mkTsService (lib.attrValues cube.services));
        };

        # NOT optional: tailscaled refuses cert requests from non-root
        # local-API clients whose uid doesn't match TS_PERMIT_CERT_UID
        # (ipn/ipnserver/server.go:390, `CanFetchCerts`), and without a
        # cert every HTTPS request dies at the handshake with nothing
        # visibly wrong here. Resolved by name at request time, so it
        # tracks whatever uid caddy's user gets. Set HERE, not in
        # system/networking/tailscale.nix, which every Linux host
        # imports -- durandal and tenacity don't run caddy.
        services.tailscale.permitCertUid = "caddy";

        # No caddy-persist.nix, same reasoning as
        # grafana.nix/forgejo.nix/golink.nix: cube has a plain
        # persistent root, so /var/lib/caddy (certs and caddy's own
        # state, already a StateDirectory upstream) survives reboots. A
        # root-wiping host importing this needs one FIRST, modeled on
        # tailscale-persist.nix, or every boot re-fetches certs.
        #
        # No firewall change either: 443/80 are deliberately not in
        # `networking.firewall.allowedTCPPorts`, since
        # `trustedInterfaces = [ "tailscale0" ]` lets tailnet traffic
        # bypass the allow-list and everything else hits default-deny.
        # Caddy binds every interface (the tailnet IP is assigned at
        # runtime) and gets 443 unprivileged from upstream
        # caddy.service's `AmbientCapabilities=CAP_NET_ADMIN
        # CAP_NET_BIND_SERVICE`.
        systemd.services.caddy = {
            # Ordering only, not a dependency -- tailscaled is enabled
            # unconditionally by system/networking/tailscale.nix. Avoids
            # the startup window where caddy asks a not-yet-running
            # tailscaled for a cert: the manager is consulted
            # per-handshake, so getting this wrong means early requests
            # failing and later ones working, which reads as flaky
            # rather than broken.
            after = [ "tailscaled.service" ];
        };
    };
}

# ── history ─────────────────────────────────────────────────────────────────
#
# 2026-08-24 to 2026-09-07 — Grafana and Forgejo were routed through here as
# `/grafana/` and `/git/` path prefixes on the one `ts-cube` hostname,
# retired once serve.nix gave each its own Tailscale Service. The two apps
# needed OPPOSITE directives (`handle` for Grafana, which served under the
# prefix; `handle_path` for Forgejo, which always served at `/`) and giving
# both the same one cost the first live switch: /grafana/ 200, /git/ 404
# (wiki/lessons-learned.md §41). Routes, mechanism and verification record:
# wiki/categories/reverse-proxy-history.md -- kept because path-prefix
# routing is the fallback if the per-Service move ever needs reverting, and
# because anything added here WITHOUT its own `svc:` name needs it again.
#
# 2026-09-08 (d7af47c5) — `tls internal` on the bare-name vhosts suppressed
# tailscale cert auto-detection for every `.ts.net` name in this file,
# breaking tailnet HTTPS host-wide until 2026-09-10. Fixed by the
# `tailscaleCert` binding above; full account, wiki/lessons-learned.md §47.
#
# 2026-09-12 to 2026-10-19 — homepage (then glance beside it) served as the
# landing page on ports 3002/3004; both removed as unused attack surface.
# The bare ts-cube host now answers 404. svc:homepage / svc:glance control-
# plane objects need vip-delete by hand.
