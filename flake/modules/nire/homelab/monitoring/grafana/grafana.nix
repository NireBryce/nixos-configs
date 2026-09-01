# Grafana: the one piece of this stack (prometheus.nix, node-exporter.nix,
# cadvisor.nix, libvirt-exporter.nix) meant to be reached off-host, and then
# only over the tailnet -- see the firewall comment below before assuming
# `openFirewall`-style options belong here.
#
# As of 2026-08-24 not reached off-host DIRECTLY: every listener in this
# stack is on loopback; nire/reverse-proxy/caddy.nix fronts it at
# https://ts-cube.moose-micro.ts.net/grafana/ with a cert from tailscaled.
# Two settings exist solely because of that (`http_addr`,
# `root_url`/`serve_from_sub_path`).
#
# RUNTIME-VERIFIED, 2026-08-23, on nire-cube: the first real switch failed
# -- the secret_key file existed but was root:root, unreadable to the
# `grafana` user. Fixed by hand; RE-BROKE the same way, found on a live
# re-check 2026-08-24 (`root:root` again, grafana.service crash-looping on
# the same permission-denied error) -- the hand fix didn't persist, and
# nothing caught the regression until someone happened to check
# `systemctl status`.
#
# `grafana-secret-key-setup` below is the fix: not a one-time manual step
# (not the `warnings` entry pointing at a manual command that used to sit
# here) but a oneshot unit running before `grafana.service` on EVERY
# activation, re-asserting ownership and permissions unconditionally -- a
# `root:root` regression, whatever causes it, self-heals on the next
# switch instead of recurring until someone looks. Modeled on forgejo's
# upstream `forgejo-secrets.service` (nixpkgs
# nixos/modules/services/misc/forgejo.nix) for the generate-if-missing
# shape, but NOT idiomatic to `services.grafana`: upstream REMOVED
# `security.secretKeyFile` in favor of the manual file-provider, its
# assertion telling the deployer to generate one -- "we won't manage this
# for you," not "we forgot to." Two load-bearing consequences in the
# script below:
#   - Only CREATE the file if missing, never regenerate. Upstream's
#     assertion warns there's no official rotation path as of 26.05 --
#     rotating breaks re-decryption of what's already in Grafana's
#     database (datasource passwords, etc), so a generator that
#     "self-heals" by overwriting is actively destructive, not redundant.
#   - Ownership/permissions ARE safe to reassert unconditionally, every
#     activation -- no rotation-style downside, and exactly the part that
#     kept regressing.
#
# No `grafana-persist.nix` alongside this the way tailscale.nix has
# tailscale-persist.nix: cube-configuration.nix's header says this host
# has a plain persistent root, not the `/root` wipe durandal/tenacity
# get, so /var/lib/grafana (sqlite db; provisioned dashboards are
# read-only file-provider entries here, not writes) survives reboots. If
# a root-wiping host ever imports this module, add one first, modeled on
# tailscale-persist.nix -- else every UI dashboard edit (anything not
# sourced from _dashboards/) is gone on reboot. secret_key itself needs
# no persistence entry: it lives at /persist/secrets/grafana-secret-key,
# not a root-relative path environment.persistence would bind-mount back
# -- same reasoning as elly's hashedPasswordFile at
# /persist/passwords/elly.
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
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
            # # description = "grafana -- dashboards over the tailnet only, for the metrics prometheus.nix collects";
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
                settings.security.secret_key = "$__file{${secretKeyPath}}";

                settings.server = {
                    http_port = 3000;

                    # Loopback, like the rest of this stack. As of
                    # 2026-08-24 nothing off-host talks to this port
                    # directly: reverse-proxy/caddy.nix terminates TLS on
                    # the tailnet and is the only client. Used to be
                    # 0.0.0.0 -- see the history note at the bottom.
                    http_addr = "127.0.0.1";

                    # BOTH, together, or the /grafana prefix breaks:
                    # root_url drives redirects/emails; serve_from_sub_path
                    # makes it serve assets under the prefix. Only the
                    # first = a login page whose CSS and JS 404 --
                    # broken-looking UI, not an obvious misconfiguration.
                    #
                    # caddy.nix routes THIS ONE with `handle`, NOT
                    # `handle_path`, so `/grafana/...` arrives with the
                    # prefix intact, which serve_from_sub_path expects;
                    # changing one side without the other breaks it.
                    # Contrast forgejo.nix: `handle_path` (stripped)
                    # because it has no serve_from_sub_path equivalent.
                    #
                    # `ts-cube.moose-micro.ts.net`, NOT `nire-cube` --
                    # this tailnet renames devices fleet-wide
                    # (networking/tailscale.nix's trap #1). The FQDN is
                    # duplicated in caddy.nix and forgejo.nix, not shared
                    # (no options in this tree, CLAUDE.md, Architecture);
                    # all three move together.
                    root_url            = "https://ts-cube.moose-micro.ts.net/grafana/";
                    serve_from_sub_path = true;

                    # Not load-bearing while `enforce_domain` is false
                    # and `root_url` is a literal (nixpkgs leaves this
                    # at "localhost"; Grafana only uses it to BUILD a
                    # default root_url). Set anyway so the two agree --
                    # flipping enforce_domain on later would otherwise
                    # reject every real request.
                    domain              = "ts-cube.moose-micro.ts.net";
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
