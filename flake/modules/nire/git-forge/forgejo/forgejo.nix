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
                        # 0.0.0.0, not loopback: this is the one service in
                        # this category meant to be reached off-host at all
                        # (over Tailscale) -- same reasoning grafana.nix
                        # gives for its own http_addr. "Tailnet only" is
                        # enforced at the firewall below, not here.
                        HTTP_ADDR = "0.0.0.0";
                        HTTP_PORT = 3001; # monitoring's grafana.nix already
                                          # took 3000 on this host.

                        # ts-cube, NOT nire-cube -- this tailnet's device
                        # names don't match `networking.hostName`
                        # (system/networking/tailscale.nix's own header has
                        # the full "TWO REAL TRAPS" writeup). Set explicitly
                        # here, unlike grafana.nix's `domain`/`root_url`
                        # (still at the nixpkgs default as of 2026-08-24) --
                        # that file's own comment flags this as the exact
                        # trap to fix "if it's ever hit"; setting it correctly
                        # from the start avoids hitting it at all.
                        DOMAIN    = "ts-cube";
                        ROOT_URL  = "http://ts-cube:3001/";

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

            # DELIBERATELY NOT adding 3001 to networking.firewall.allowedTCPPorts
            # (system/networking/networking.nix). Same mechanism grafana.nix
            # already relies on: `trustedInterfaces = [ "tailscale0" ]` in
            # that same file means traffic arriving over the tailnet bypasses
            # the allow-list entirely, traffic arriving on any other
            # interface hits the default-deny -- so leaving this port out of
            # the allow-list is what keeps it off the LAN. Port 22 (ssh) IS
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
