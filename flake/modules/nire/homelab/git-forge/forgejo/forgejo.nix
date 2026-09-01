# Forgejo: a self-hosted git forge, tailnet-only. Added 2026-08-24,
# cube-only, own category (`nire/git-forge/`) -- the category-as-optionality
# mechanism CLAUDE.md's Architecture section gives `monitoring` and
# `virtualization`; nothing here for the handhelds, and no reason to force
# durandal to carry it. Named `git-forge`, not `forgejo`: both category and
# module named `forgejo` would declare `flake.modules.nixos.forgejo` twice
# and silently merge (the `containers`/`podman.nix` collision CLAUDE.md
# documents; `just modules` caught it pre-ship).
#
# Checked against pinned nixpkgs' actual
# nixos/modules/services/misc/forgejo.nix for whether Forgejo needs
# grafana.nix's hand-created-secret dance. It does not: `services.forgejo`
# ships `forgejo-secrets.service`, a oneshot generating
# SECRET_KEY/INTERNAL_TOKEN/JWT_SECRET under `${customDir}/conf/` on first
# run, no-op if the files exist. Nothing hand-created, no `warnings` entry.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);

        # Read from /persist/secrets/tailnet-fqdn (reverse-proxy/
        # tailnet-fqdn-refresh.nix), not a literal -- see caddy.nix's
        # header for why and its eval-time-vs-runtime caveat. Same read
        # expression duplicated in caddy.nix, grafana.nix, glance.nix.
        tailnetFqdn =
            let path = /persist/secrets/tailnet-fqdn;
            in if builtins.pathExists path
               then lib.removeSuffix "\n" (builtins.readFile path)
               else "ts-cube.tailnet-fqdn-unset.invalid";
    in {
        flake.modules.nixos.${moduleName} = { config, ... }: {
            services.forgejo = {
                enable  = true;
                # sqlite3 (the module default), not postgres/mysql: a
                # single-user forge, no concurrent-write load needing a real
                # RDBMS, and no second service/category to stand up.
                # database.type left at default on purpose.

                settings = {
                    server = {
                        # Loopback since 2026-08-24: nothing off-host
                        # connects here. nire/reverse-proxy/caddy.nix accepts
                        # on the tailnet, terminates TLS from tailscaled's
                        # cert, proxies to this port over 127.0.0.1. Used to
                        # be 0.0.0.0 -- history note at the bottom.
                        #
                        # Quieter second effect: Forgejo's LOCAL_ROOT_URL
                        # defaults to `http://%(HTTP_ADDR)s:%(HTTP_PORT)s/`
                        # (nixpkgs doesn't override), so 0.0.0.0 built
                        # self-referential URLs from an any-address; now it
                        # resolves to http://127.0.0.1:3001/, as it always
                        # should have.
                        HTTP_ADDR = "127.0.0.1";
                        HTTP_PORT = 3001; # monitoring's grafana.nix already
                                          # took 3000 on this host.

                        # ts-cube, NOT nire-cube -- tailnet device names
                        # don't match `networking.hostName`
                        # (system/networking/tailscale.nix's "TWO REAL
                        # TRAPS"). These deliberately DISAGREE; not a typo:
                        #
                        #   - ROOT_URL is what the browser sees: full
                        #     https:// FQDN under the /git/ prefix caddy.nix
                        #     mounts this at; trailing slash required --
                        #     Forgejo appends every link to it. It does NOT
                        #     make Forgejo serve under that prefix (no
                        #     serve_from_sub_path; the app always serves at
                        #     `/` -- live-verified 2026-08-24: `curl
                        #     127.0.0.1:3001/` 200, `.../git/` 404), so
                        #     caddy.nix STRIPS the prefix here (`handle_path`)
                        #     but keeps it for Grafana (`handle`); without
                        #     the strip, a 404 on every page -- how the
                        #     asymmetry was found.
                        #   - DOMAIN builds the SSH clone URLs (SSH_DOMAIN
                        #     defaults to it); git+ssh bypasses caddy for the
                        #     host's sshd on port 22 (below). Short `ts-cube`
                        #     keeps clone URLs `forgejo@ts-cube:...`, and
                        #     stays a literal here -- it's just this host's
                        #     short device name, not the tailnet's name.
                        #
                        # `tailnetFqdn` (this file's `let`) reads the FQDN
                        # from /persist/secrets/tailnet-fqdn, the same file
                        # caddy.nix/grafana.nix/glance.nix read; not shared
                        # as an option (nothing declares options, CLAUDE.md
                        # Architecture), but the VALUE is centralized there.
                        DOMAIN    = "ts-cube";
                        ROOT_URL  = "https://${tailnetFqdn}/git/";

                        # DISABLE_SSH at default (false); START_SSH_SERVER
                        # unset, so false too -- git+ssh goes through the
                        # HOST's OpenSSH (system/ssh/ssh.nix, on every NixOS
                        # host), not a second sshd. Forgejo manages
                        # ~forgejo/.ssh/authorized_keys itself as keys are
                        # added via the web UI; ordinary per-user
                        # authorized_keys lookup does the rest, no
                        # AuthorizedKeysCommand. Clone URLs
                        # `forgejo@ts-cube:...`, port 22 -- the port normal
                        # ssh already uses, so no second port, just a second
                        # user with Forgejo-managed keys against sshd.
                    };

                    service = {
                        # Single-user instance behind a tailnet only elly's
                        # devices reach -- self-registration stays closed. A
                        # new user is a `forgejo admin user create` away.
                        DISABLE_REGISTRATION = true;
                    };
                };
            };

            # STILL no 3001 in networking.firewall.allowedTCPPorts
            # (system/networking/networking.nix) -- but since 2026-08-24 the
            # loopback bind above is what keeps this off the LAN, not the
            # firewall (now the second line). The tailnet-facing port is
            # caddy's 443; reverse-proxy/caddy.nix carries that reasoning:
            # its `trustedInterfaces = [ "tailscale0" ]` lets tailnet
            # traffic bypass the allow-list, anything else hits
            # default-deny. Port 22 IS in the allow-list on every NixOS host
            # for ordinary ssh -- git+ssh rides that existing exposure, not
            # a new one.
            #
            # Same caveat grafana.nix documents: trustedInterfaces trusts
            # the WHOLE tailscale0 interface, not just this port -- the
            # host's existing security model, not something this module
            # adds.

            # No forgejo-persist.nix, same reasoning grafana.nix gives for
            # skipping one: cube has a plain persistent root
            # (cube-configuration.nix's header), not the
            # durandal/tenacity/lego `/root` wipe, so /var/lib/forgejo
            # (repos, sqlite db, self-generated secrets under
            # `custom/conf/`) survives reboots. If a host that DOES wipe
            # root ever imports this, add one first, modeled on
            # tailscale-persist.nix.

            # Admin account bootstrap. Added 2026-08-26 --
            # DISABLE_REGISTRATION closes self-signup and there is no setup
            # wizard (useWizard default false, INSTALL_LOCK forced true
            # above), so nothing creates the FIRST account either. Declared
            # here rather than run by hand: reproducible from this repo +
            # sops, not one-off machine state.
            #
            # sopsFile unset -- defaults to `config.sops.defaultSopsFile`
            # (secrets.yaml, set in nire/system/secrets/sops.nix, imported
            # by every Linux host via `system`). Declared HERE, not beside
            # the syncthing-* secrets in sops.nix, on purpose: `git-forge`
            # is cube-only, and a secret in sops.nix decrypts on every
            # `system` host (durandal/tenacity/lego included, none running
            # Forgejo); declaring it here means it decrypts only where
            # imported.
            sops.secrets.forgejo-admin-password = {
                owner = config.services.forgejo.user;
                group = config.services.forgejo.group;
                mode  = "0400";
            };

            # Deliberately RESETS the password to the sops value on every
            # activation, not the create-if-missing/never-touch shape
            # forgejo-secrets.service and grafana-secret-key-setup.service
            # use for SECRET_KEY-style values -- considered: a password,
            # unlike a signing key, has no other state that breaks when it
            # changes, and nix+sops is meant to be its sole source of truth.
            # Tradeoff: a hand change in the web UI is silently reverted on
            # the next `just switch`.
            #
            # `admin user create` first (covers the first activation); if it
            # fails -- the only realistic failure once forgejo.service is
            # healthy is "user already exists" -- `admin user
            # change-password` runs instead. Ordered after/wants
            # forgejo.service rather than duplicating its `forgejo migrate`
            # preStart: a Type=notify unit reports active only after
            # preStart (the migration) completed.
            systemd.services.forgejo-admin-bootstrap = {
                description = "Ensure the Forgejo admin account exists with the sops-managed password";
                after       = [ "forgejo.service" ];
                wants       = [ "forgejo.service" ];
                wantedBy    = [ "multi-user.target" ];
                path        = [ config.services.forgejo.package ];

                script = ''
                    set -euo pipefail
                    USERNAME=elly
                    EMAIL=nire@computernope.net
                    CONFIG=${config.services.forgejo.customDir}/conf/app.ini
                    PASSWORD_FILE=${config.sops.secrets.forgejo-admin-password.path}

                    if ! forgejo --config "$CONFIG" admin user create \
                        --username "$USERNAME" \
                        --email "$EMAIL" \
                        --password "$(cat "$PASSWORD_FILE")" \
                        --admin \
                        --must-change-password=false
                    then
                        forgejo --config "$CONFIG" admin user change-password \
                            --username "$USERNAME" \
                            --password "$(cat "$PASSWORD_FILE")"
                    fi
                '';

                serviceConfig = {
                    Type             = "oneshot";
                    RemainAfterExit  = true;
                    User             = config.services.forgejo.user;
                    Group            = config.services.forgejo.group;
                };
            };
        };
}

# ── history ─────────────────────────────────────────────────────────────────
#
# 2026-08-24 — this used to listen on 0.0.0.0 with a plain-HTTP ROOT_URL
#
# For the few hours between this file being written and
# nire/reverse-proxy/caddy.nix being added, `settings.server` read
# HTTP_ADDR = "0.0.0.0" -- commented as the one service in the category
# meant to be reached off-host at all (over Tailscale), "tailnet only"
# enforced at the firewall, grafana.nix's reasoning at the time -- and
# ROOT_URL = "http://ts-cube:3001/". Accurate for that arrangement: nothing
# else on the host could accept the connection, and `trustedInterfaces =
# [ "tailscale0" ]` was the only thing between port 3001 and the LAN.
# caddy.nix removed that constraint for both this and Grafana in one change;
# the listener moved to loopback and the URL gained TLS and a path prefix.
#
# The old comment also noted DOMAIN/ROOT_URL were set here "unlike
# grafana.nix's, still at the nixpkgs default" -- no longer a difference:
# grafana.nix sets its `root_url` now too, same reason plus the sub-path
# one.
