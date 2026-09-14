# Grafana: the one piece of this stack (prometheus.nix, node-exporter.nix,
# cadvisor.nix, libvirt-exporter.nix) meant to be reached off-host, and then
# only over the tailnet. Every listener in the stack, this one included, is
# on LOOPBACK: Grafana is reached at https://grafana.moose-micro.ts.net/,
# its own Tailscale Services name, and Caddy is what terminates TLS for it
# (serve.nix only raw-forwards TCP -- Tailscale Services cannot terminate
# HTTPS declaratively on this version). Confirmed working 2026-09-07.
#
# Kept in the wiki, not restated here: the secret_key trap's full account
# and both of Grafana's passwords, wiki/categories/monitoring.md,
# `-for-agents.md` and `monitoring-history.md`; how to actually sign in,
# wiki/homelab/grafana.md. Traps sit next to the options.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);

        secretKeyPath = "/persist/secrets/grafana-secret-key";

        # Fixed, not auto-generated, so the dashboard JSON below can
        # reference it directly instead of needing a templated
        # `${DS_PROMETHEUS}` variable resolved through Grafana's import
        # flow -- datasource and dashboard are both provisioned from
        # files by the same module; nothing to resolve at import time.
        prometheusDatasourceUid = "prometheus-cube";
    in {
        # `pkgs` bound HERE, on the inner NixOS-module function, not the
        # outer flake-parts one -- flake-parts doesn't inject a `pkgs`
        # into `_module.args` at this scope (evaluating it errors:
        # "attribute 'pkgs' missing"). Same pattern
        # zsh.nix/bash.nix/pipewire.nix/etc. use throughout this tree.
        flake.modules.nixos.${moduleName} = { pkgs, config, ... }: {
            # # description = "grafana -- dashboards over the tailnet only, for the metrics prometheus.nix collects";

            # `owner`, not the root:root default -- grafana.service runs as
            # the `grafana` user and reads this file itself at start, the
            # same way it reads secretKeyPath. Getting that wrong is the
            # exact failure this module's header records for secret_key:
            # the file existed, was root:root, and Grafana could not read
            # it. Do not drop the owner and assume 0400 root is fine.
            sops.secrets.grafana-admin-password = {
                owner = "grafana";
            };

            services.grafana = {
                enable = true;

                # 26.05 made this a hard eval-time assertion (nixpkgs
                # grafana.nix: "doesn't have a default value anymore...
                # use a file-provider"). `$__file{...}` is Grafana's
                # provider syntax, read by Grafana at service start,
                # never by Nix -- satisfies the assertion without the
                # file existing at eval time (unlike
                # environment.persistence entries). It DOES need to
                # exist, readable by `grafana`, when grafana.service
                # starts; `grafana-secret-key-setup` below guarantees
                # that every activation. See the header for why a
                # oneshot unit, not a `warnings` entry.
                settings = {
                    security.secret_key       = "$__file{${secretKeyPath}}";

                    # **First start only, and that is the entire point.**
                    # Grafana's own defaults.ini says so outright: "default
                    # admin password, can be changed before first start of
                    # grafana, or in profile settings". It is read when Grafana
                    # CREATES the admin user; on an instance whose admin user
                    # already exists it does nothing at all.
                    #
                    # So this does NOT manage cube's current password (changed
                    # by hand 2026-09-13) and is not drift enforcement. What it
                    # removes is the fail-open window: before this, a fresh or
                    # rebuilt instance came up on Grafana's published
                    # `admin`/`admin` with only the tailnet in front of it, and
                    # stayed there until a human noticed. Now it comes up on a
                    # sops value instead.
                    #
                    # Making sops authoritative over the LIVE password is a
                    # different mechanism -- a oneshot running `grafana-cli
                    # admin reset-admin-password` per activation, the shape
                    # forgejo-admin-bootstrap uses. Deliberately not done here:
                    # it would overwrite a hand-set password on every switch.
                    security.admin_password =
                        "$__file{${config.sops.secrets.grafana-admin-password.path}}";

                    server = {
                        http_port = 3000;

                        # Loopback, like the rest of this stack. As of
                        # 2026-08-24 nothing off-host talks to this port
                        # directly: reverse-proxy/caddy.nix terminates TLS on
                        # the tailnet and is the only client. Used to be
                        # 0.0.0.0 -- see the history note at the bottom.
                        http_addr = "127.0.0.1";

                        # NO LONGER behind a path prefix, as of the
                        # Grafana has its own Tailscale Services name
                        # (`svc:grafana`), so it serves at plain root --
                        # `serve_from_sub_path` dropped (defaults false),
                        # and `root_url` is that name, not
                        # `ts-cube.../grafana/`. Verified end to end
                        # 2026-09-07; the retired path-prefix route is in
                        # wiki/categories/reverse-proxy-history.md if this
                        # ever needs reverting.
                        #
                        # The service hostname is `<name>.<tailnet MagicDNS
                        # suffix>`, NOT the device name `ts-cube` the old
                        # prefix used -- confirmed against a real TLS
                        # handshake from another tailnet host, 2026-09-07.
                        root_url = "https://grafana.moose-micro.ts.net/";

                        # Not load-bearing while `enforce_domain` is false
                        # and `root_url` is a literal (nixpkgs leaves this
                        # at "localhost"; Grafana only uses it to BUILD a
                        # default root_url). Set anyway so the two agree --
                        # flipping enforce_domain on later would otherwise
                        # reject every real request.
                        domain   = "grafana.moose-micro.ts.net";
                    };
                };

                provision = {
                    enable = true;

                    datasources.settings.datasources = [
                        {
                            name      = "Prometheus";
                            uid       = prometheusDatasourceUid;
                            type      = "prometheus";
                            access    = "proxy";
                            url       = "http://127.0.0.1:9090"; # prometheus.nix, over loopback
                            isDefault = true;
                        }
                    ];

                    dashboards.settings.providers = [
                        {
                            name    = "nire-cube";
                            type    = "file";
                            options.path = ./_dashboards; # underscore-prefixed so import-tree
                                                           # (flake.nix's `import-tree ./modules`)
                                                           # never tries to import the JSON in
                                                           # here as a flake-parts module -- same
                                                           # convention VMs/_lib/ uses, see that
                                                           # file's header for the mechanism.
                        }
                    ];
                };
            };

            # Generates secretKeyPath if missing, and unconditionally
            # re-asserts ownership/mode every activation -- the actual
            # fix for the header's ownership regression. `before`+
            # `wantedBy` on grafana.service (not ExecStartPre) keeps it
            # a separate, inspectable unit: `systemctl status
            # grafana-secret-key-setup` shows what it did, apart from
            # grafana.service's log.
            #
            # `before`/`wantedBy` are additive on `services.grafana`'s
            # own `systemd.services.grafana` (list-type options merge),
            # not a redeclaration -- like nixpkgs' forgejo.nix extending
            # `services.openssh.settings.AcceptEnv` from outside that
            # module.
            systemd.services.grafana-secret-key-setup = {
                description = "Generate/repair Grafana's secret_key file and its ownership";
                before      = [ "grafana.service" ];
                wantedBy    = [ "grafana.service" ];

                serviceConfig = {
                    Type            = "oneshot";
                    RemainAfterExit = true;
                };

                # Deliberately two separate steps, not "regenerate every
                # time": creating (only if missing) and fixing
                # ownership/mode (always) have different safety
                # properties -- overwriting an EXISTING key would be
                # destructive, not redundant (see the header).
                script = ''
                    set -euo pipefail
                    mkdir -p "$(dirname '${secretKeyPath}')"

                    if [ ! -s '${secretKeyPath}' ]; then
                        umask 077
                        ${pkgs.openssl}/bin/openssl rand -hex 32 > '${secretKeyPath}'
                    fi

                    chown grafana:grafana '${secretKeyPath}'
                    chmod 600 '${secretKeyPath}'
                '';
            };

            # STILL no 3000 in networking.firewall.allowedTCPPorts
            # (networking.nix, `system` category) -- but as of 2026-08-24
            # that is no longer what keeps Grafana off the LAN:
            # `http_addr` above is (loopback; nothing on any other
            # interface to allow or deny). The firewall is now the second
            # line.
            #
            # What IS exposed on the tailnet is caddy's 443, same
            # reasoning one file over: `trustedInterfaces =
            # [ "tailscale0" ]` lets tailnet traffic bypass the
            # allow-list, everything else hits default-deny. See
            # reverse-proxy/caddy.nix.
            #
            # Caveat: trustedInterfaces trusts the WHOLE interface, not
            # a port -- "anything over Tailscale is already trusted", the
            # blanket trust ssh/kde-connect/etc. get here. Existing
            # security model, not introduced by this module. Per
            # networking/tailscale.nix's "TWO REAL TRAPS": a tailnet ACL
            # denying member-to-member traffic makes this unreachable
            # with every setting here correct -- fixed in the admin
            # console, not here.
        };
}

# ── history ─────────────────────────────────────────────────────────────────
#
# 2026-08-24 — this used to bind 0.0.0.0, and `root_url` used to be unset
#
# From 2026-08-23 to 2026-08-24 `settings.server.http_addr` was "0.0.0.0",
# commented as the one service here that had to be reachable off-host (over
# Tailscale), unlike the loopback-only node-exporter/cadvisor/
# libvirt-exporter/prometheus, with "tailnet only" enforced at the firewall.
# True at the time: nothing else on the host could accept the connection, so
# `trustedInterfaces = [ "tailscale0" ]` was the ONLY thing between port
# 3000 and the LAN. Adding nire/reverse-proxy/caddy.nix removed that
# constraint -- caddy accepts on the tailnet, terminates TLS with a cert
# from tailscaled, connects over loopback -- so the listener moved back in
# line with the rest of the stack.
#
# The same comment predicted "invalid redirect" errors after login would
# mean `domain`/`root_url` needing this host's MagicDNS name (`ts-cube` ...
# NOT `nire-cube`). `root_url` is set now, for that predicted reason plus
# one more: behind a path prefix Grafana needs `root_url` AND
# `serve_from_sub_path`, and the FQDN must be the full
# `ts-cube.moose-micro.ts.net`, not the short name that comment guessed at
# -- it is what the browser has in its address bar.
