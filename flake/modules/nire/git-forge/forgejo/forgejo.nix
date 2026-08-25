# Forgejo: a self-hosted git forge, reachable over the tailnet only. Added
# 2026-08-24, cube-only, own category (`nire/git-forge/`) for the same "if
# something shared needs to be optional, a category is the mechanism"
# reason `monitoring` and `virtualization` already give (see CLAUDE.md's
# Architecture section) -- there's nothing here for the handhelds and no
# reason to force durandal to carry it either. The category is named
# `git-forge`, not `forgejo`: naming both the category and its one module
# `forgejo` would declare the same `flake.modules.nixos.forgejo` attribute
# twice and silently merge -- the exact `containers`/`podman.nix` collision
# CLAUDE.md's Architecture section already documents, hit for real writing
# this module and caught by `just modules` before it shipped.
#
# Read against the pinned nixpkgs' actual
# nixos/modules/services/misc/forgejo.nix before writing this, per this
# repo's own "read upstream source rather than guessing at options" rule --
# specifically to find out whether Forgejo needed the same hand-created-
# secret dance `grafana.nix` documents. It does not: `services.forgejo`
# ships its own `forgejo-secrets.service`, a oneshot that generates
# SECRET_KEY/INTERNAL_TOKEN/JWT_SECRET itself under
# `${customDir}/conf/` the first time it runs, and no-ops if those files
# already exist. Nothing to create by hand, no `warnings` entry needed here.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            services.forgejo = {
                enable  = true;
                # sqlite3 (the module default) rather than postgres/mysql --
                # this is a single-user homelab forge, not something with
                # concurrent-write load a real RDBMS is needed for, and it
                # means no second service/category to stand up just for this.
                # database.type left at its default on purpose.

                settings = {
                    server = {
                        # Loopback as of 2026-08-24: nothing off-host
                        # connects here any more.
                        # nire/reverse-proxy/caddy.nix accepts on the tailnet,
                        # terminates TLS with a cert from tailscaled, and
                        # proxies to this port over 127.0.0.1. This used to be
                        # 0.0.0.0 -- see the history note at the bottom of
                        # this file.
                        #
                        # Second, quieter effect of the same line: Forgejo's
                        # own LOCAL_ROOT_URL defaults to
                        # `http://%(HTTP_ADDR)s:%(HTTP_PORT)s/`, which nixpkgs
                        # doesn't override, so with 0.0.0.0 it was building
                        # self-referential URLs out of an any-address. It now
                        # resolves to http://127.0.0.1:3001/, which is what it
                        # always should have been.
                        HTTP_ADDR = "127.0.0.1";
                        HTTP_PORT = 3001; # monitoring's grafana.nix already
                                          # took 3000 on this host.

                        # ts-cube, NOT nire-cube -- this tailnet's device
                        # names don't match `networking.hostName`
                        # (system/networking/tailscale.nix's own header has
                        # the full "TWO REAL TRAPS" writeup).
                        #
                        # These two deliberately DISAGREE now, and that is
                        # not a typo:
                        #
                        #   - ROOT_URL is what the browser sees, so it is the
                        #     full https:// FQDN, under the /git/ prefix
                        #     caddy.nix mounts this at. The trailing slash is
                        #     required; Forgejo builds every link by
                        #     appending to this. It does NOT make Forgejo
                        #     serve under that prefix -- there is no
                        #     serve_from_sub_path equivalent here, this app
                        #     always serves at `/`. Verified live on cube
                        #     2026-08-24: `curl 127.0.0.1:3001/` is 200,
                        #     `curl 127.0.0.1:3001/git/` is 404. So caddy.nix
                        #     STRIPS the prefix for this route
                        #     (`handle_path`) while leaving it on for
                        #     Grafana's (`handle`). Setting ROOT_URL here
                        #     without that strip is a 404 on every page, which
                        #     is how the asymmetry was found.
                        #   - DOMAIN is what SSH clone URLs are built from
                        #     (SSH_DOMAIN defaults to it), and git+ssh does
                        #     NOT go through caddy -- it goes to this host's
                        #     own sshd on port 22, see the note below. So it
                        #     stays the short `ts-cube`, which is what makes
                        #     clone URLs read `forgejo@ts-cube:...` rather
                        #     than dragging the whole FQDN along.
                        #
                        # The FQDN is duplicated in caddy.nix and
                        # grafana.nix rather than shared, because nothing in
                        # this tree declares options (CLAUDE.md,
                        # Architecture); all three move together.
                        DOMAIN    = "ts-cube";
                        ROOT_URL  = "https://ts-cube.moose-micro.ts.net/git/";

                        # DISABLE_SSH left at its default (false), and
                        # START_SSH_SERVER is NOT set here, so it stays at
                        # the Forgejo/Gitea default of false too -- meaning
                        # git+ssh goes through the HOST's own OpenSSH
                        # (system/ssh/ssh.nix, already enabled on every
                        # NixOS host) rather than a second sshd listening on
                        # its own port. Forgejo manages
                        # ~forgejo/.ssh/authorized_keys itself as users add
                        # keys through the web UI; ordinary OpenSSH
                        # per-user authorized_keys lookup does the rest, no
                        # AuthorizedKeysCommand needed. Clone URLs are
                        # `forgejo@ts-cube:...`, port 22 -- same port normal
                        # ssh already uses on this host, so this doesn't add
                        # a second port to reason about, only a second user
                        # that can authenticate against sshd with its own
                        # (Forgejo-managed) keys.
                    };

                    service = {
                        # Single-user homelab instance behind a tailnet only
                        # elly's own devices reach -- no reason to leave
                        # self-registration open to whoever else is on the
                        # tailnet. A new user is a `forgejo admin user
                        # create` away if this repo ever wants more than
                        # one.
                        DISABLE_REGISTRATION = true;
                    };
                };
            };

            # STILL not adding 3001 to networking.firewall.allowedTCPPorts
            # (system/networking/networking.nix) -- but since 2026-08-24 that
            # is no longer what keeps this off the LAN. HTTP_ADDR above is:
            # the port is bound on loopback, so there is nothing on another
            # interface to allow or deny, and the firewall became the second
            # line rather than the only one. The tailnet-facing port is now
            # caddy's 443, and reverse-proxy/caddy.nix carries the same
            # reasoning for it: `trustedInterfaces = [ "tailscale0" ]` in
            # that same file means traffic arriving over the tailnet bypasses
            # the allow-list entirely, traffic arriving on any other
            # interface hits the default-deny. Port 22 (ssh) IS
            # already in that allow-list, on every NixOS host, for ordinary
            # ssh -- Forgejo's git+ssh access rides on that existing,
            # already-LAN-reachable port and inherits its existing exposure,
            # not a new one this module introduces.
            #
            # Same caveat grafana.nix documents: trustedInterfaces trusts the
            # WHOLE tailscale0 interface, not just this port -- the existing
            # security model on this host, not something this module adds.

            # No forgejo-persist.nix alongside this, same reasoning
            # grafana.nix gives for skipping a grafana-persist.nix: cube has
            # a plain persistent root (cube-configuration.nix's own header),
            # not the durandal/tenacity/lego `/root` wipe, so
            # /var/lib/forgejo (repos, sqlite db, the self-generated secrets
            # under its `custom/conf/`) just survives reboots with no
            # environment.persistence entry needed. If this module is ever
            # imported by a host that DOES wipe root, add one first, modeled
            # on tailscale-persist.nix.
        };
}

# ── history ─────────────────────────────────────────────────────────────────
#
# 2026-08-24 — this used to listen on 0.0.0.0 with a plain-HTTP ROOT_URL
#
# For the few hours between this file being written and
# nire/reverse-proxy/caddy.nix being added, `settings.server` read:
#
#   > HTTP_ADDR = "0.0.0.0";   # 0.0.0.0, not loopback: this is the one
#   >                          # service in this category meant to be reached
#   >                          # off-host at all (over Tailscale) -- same
#   >                          # reasoning grafana.nix gives for its own
#   >                          # http_addr. "Tailnet only" is enforced at the
#   >                          # firewall below, not here.
#   > ROOT_URL  = "http://ts-cube:3001/";
#
# Accurate for the arrangement it described: with nothing else on this host
# able to accept the connection, Forgejo had to take it itself, and
# `trustedInterfaces = [ "tailscale0" ]` was the only thing between port 3001
# and the LAN. caddy.nix removed that constraint for both this and Grafana in
# one change; the listener moved to loopback and the URL gained TLS and a
# path prefix.
#
# The old comment also noted that DOMAIN/ROOT_URL were set here "unlike
# grafana.nix's, still at the nixpkgs default" -- that is no longer a
# difference between the two files. grafana.nix sets its `root_url` now too,
# for the same reason plus the sub-path one.
