# Grafana: the one piece of this stack (prometheus.nix, node-exporter.nix,
# cadvisor.nix, libvirt-exporter.nix) meant to be reached off-host, and then
# only over the tailnet -- see the firewall comment below before assuming
# `openFirewall`-style options belong here.
#
# As of 2026-08-24 it is not reached off-host DIRECTLY: every listener in
# this stack, this one included, is on loopback, and
# nire/reverse-proxy/caddy.nix fronts it at
# https://ts-cube.moose-micro.ts.net/grafana/ with a cert from tailscaled.
# Two settings here exist solely because of that (`http_addr`,
# `root_url`/`serve_from_sub_path`) and are commented as such.
#
# RUNTIME-VERIFIED, 2026-08-23, on nire-cube: `just switch` activates cleanly
# and every other unit in this stack came up, but grafana.service itself
# failed on the first real switch -- the secret_key file existed but was
# root:root, unreadable to the `grafana` user the service runs as. Fixed by
# hand that day; RE-BROKE the same way, found on a live re-check 2026-08-24
# (`root:root` again, `grafana.service` actively crash-looping on the same
# permission-denied error) -- whatever fixed it the first time didn't
# persist, and nothing caught the regression until someone happened to
# check `systemctl status` again.
#
# `grafana-secret-key-setup` below is the fix for that: not a one-time
# manual step (a `warnings` entry pointing at a shell command used to sit
# here instead), but a oneshot unit that runs before `grafana.service` on
# EVERY activation and unconditionally re-asserts ownership and
# permissions -- so a `root:root` regression, whatever causes it, self-heals
# on the next switch instead of silently recurring until someone happens to
# look. Modeled on `services.forgejo`'s own upstream `forgejo-secrets.service`
# (nixpkgs nixos/modules/services/misc/forgejo.nix) for the generate-if-
# missing shape, but NOT idiomatic to `services.grafana` specifically --
# checked upstream `grafana.nix` before writing this: it used to have a
# `security.secretKeyFile` option and that was REMOVED in favor of the
# manual file-provider, with the module's own assertion message telling the
# deployer to generate one themselves. Upstream's stance here is "we won't
# manage this for you," not "we forgot to." Two things that follow from
# that, both load-bearing in the script below:
#   - Only CREATE the file if it's missing, never regenerate an existing
#     one. Upstream's own assertion text warns there's no official way to
#     rotate secret_key as of 26.05 -- doing so breaks re-decryption of
#     whatever's already encrypted in Grafana's own database (datasource
#     passwords, etc). A generator that "self-heals" by overwriting content
#     would be actively destructive, not just redundant.
#   - Ownership/permissions ARE safe to reassert unconditionally, every
#     activation -- that part has no rotation-style downside, which is
#     exactly the part that kept regressing.
#
# No `grafana-persist.nix` alongside this the way tailscale.nix has
# tailscale-persist.nix: cube-configuration.nix's own header says this host
# was installed with a plain persistent root, not the `/root` wipe
# durandal/tenacity get, so /var/lib/grafana (sqlite db, provisioned
# dashboards land here as read-only file-provider entries, not writes) just
# survives reboots with no environment.persistence entry needed. If this
# module is ever imported by a host that DOES wipe root, add one first,
# modeled on tailscale-persist.nix -- otherwise every dashboard edit made
# through the UI (anything not sourced from _dashboards/) is gone on reboot.
# The secret_key file itself would NOT need a persistence entry even then --
# it already lives directly at /persist/secrets/grafana-secret-key, not a
# root-relative path environment.persistence would need to bind-mount back;
# same reasoning elly's hashedPasswordFile sits at /persist/passwords/elly
# rather than under /var/lib/... plus a bind-mount entry.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);

        secretKeyPath = "/persist/secrets/grafana-secret-key";

        # Fixed rather than left to auto-generate, so the dashboard JSON below
        # can reference it directly instead of needing a templated
        # `${DS_PROMETHEUS}` variable resolved through Grafana's import flow --
        # this datasource and that dashboard are both provisioned from files by
        # the same module, so nothing needs resolving at import time.
        prometheusDatasourceUid = "prometheus-cube";
    in {
        # `pkgs` bound HERE, on the inner NixOS-module function, not the
        # outer flake-parts one above -- flake-parts doesn't inject a `pkgs`
        # into `_module.args` at this scope (evaluating it errors: "attribute
        # 'pkgs' missing"). Same pattern zsh.nix/bash.nix/pipewire.nix/etc.
        # already use throughout this tree; hit the eval error writing this
        # before checking those first.
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
            # # description = "grafana -- dashboards over the tailnet only, for the metrics prometheus.nix collects";
            services.grafana = {
                enable = true;

                # 26.05 turned this from "has a default" into a hard eval-time
                # assertion (nixpkgs grafana.nix: "doesn't have a default value
                # anymore... use a file-provider"). `$__file{...}` is Grafana's
                # own provider syntax -- read by Grafana itself at service
                # start, never by Nix, so this satisfies the assertion without
                # needing the file to exist at eval time (unlike
                # environment.persistence entries, which do need their source
                # to exist). It DOES need to exist -- and be readable by the
                # `grafana` user -- by the time grafana.service actually
                # starts; `grafana-secret-key-setup` below is what guarantees
                # that on every activation, not just the first one. See this
                # file's own header for why that's a oneshot unit rather than
                # a `warnings` entry pointing at a manual command.
                settings.security.secret_key = "$__file{${secretKeyPath}}";

                settings.server = {
                    http_port = 3000;

                    # Loopback, exactly like the rest of this stack
                    # (node-exporter, cadvisor, libvirt-exporter, prometheus).
                    # As of 2026-08-24 nothing off-host talks to this port
                    # directly: reverse-proxy/caddy.nix terminates TLS on the
                    # tailnet and is the only client. This used to be 0.0.0.0
                    # -- see the history note at the bottom of this file for
                    # why, and for what changed.
                    http_addr = "127.0.0.1";

                    # BOTH of these, together, or the /grafana prefix breaks.
                    # root_url alone tells Grafana what to put in redirects
                    # and emails; serve_from_sub_path is what makes it
                    # actually serve its own assets under that prefix.
                    # Setting only the first gives a login page whose CSS and
                    # JS 404 -- a broken-looking UI, not an obvious
                    # misconfiguration.
                    #
                    # caddy.nix routes THIS ONE with `handle`, NOT
                    # `handle_path`, so `/grafana/...` arrives here with the
                    # prefix intact, which is what serve_from_sub_path
                    # expects. Changing one side without the other breaks it.
                    # Note the contrast with forgejo.nix next door, which
                    # gets `handle_path` (prefix stripped) precisely because
                    # it has no serve_from_sub_path equivalent -- the two
                    # apps want opposite things from the same proxy.
                    #
                    # `ts-cube.moose-micro.ts.net`, NOT `nire-cube` -- this
                    # tailnet renames its devices
                    # (networking/tailscale.nix's trap #1). The FQDN is
                    # duplicated in caddy.nix and forgejo.nix rather than
                    # shared, because nothing in this tree declares options
                    # (CLAUDE.md, Architecture); all three move together.
                    root_url            = "https://ts-cube.moose-micro.ts.net/grafana/";
                    serve_from_sub_path = true;

                    # Not load-bearing while `enforce_domain` is false and
                    # `root_url` is a literal (nixpkgs leaves this at
                    # "localhost", and Grafana only uses it to BUILD a
                    # default root_url). Set anyway so the two agree: a
                    # reader comparing them shouldn't have to work out which
                    # one wins, and flipping enforce_domain on later would
                    # otherwise reject every real request.
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
            # re-asserts its ownership/mode every activation -- the actual
            # fix for the ownership regression this file's own header
            # documents. `before`+`wantedBy` on grafana.service (rather than
            # folding this into grafana.service's own ExecStartPre) keeps it
            # a separate, independently-inspectable unit -- `systemctl status
            # grafana-secret-key-setup` shows exactly what it did, separate
            # from grafana.service's own log.
            #
            # `before`/`wantedBy` are additive on `services.grafana`'s own
            # `systemd.services.grafana` (list-type options merge), not a
            # redeclaration -- same pattern `services.openssh.settings.
            # AcceptEnv` extension in nixpkgs' own forgejo.nix uses to extend
            # a module-owned option from outside that module.
            systemd.services.grafana-secret-key-setup = {
                description = "Generate/repair Grafana's secret_key file and its ownership";
                before      = [ "grafana.service" ];
                wantedBy    = [ "grafana.service" ];

                serviceConfig = {
                    Type            = "oneshot";
                    RemainAfterExit = true;
                };

                # Deliberately two separate steps, not "regenerate every
                # time": creating (only if missing) and fixing ownership/mode
                # (always) have different safety properties -- see this
                # file's own header for why overwriting an EXISTING key would
                # be destructive, not just redundant.
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

            # STILL deliberately not adding 3000 to
            # networking.firewall.allowedTCPPorts (networking.nix, part of the
            # `system` category this host already imports) -- but as of
            # 2026-08-24 that is no longer the thing keeping Grafana off the
            # LAN. `http_addr` above is: the port is bound on loopback, so
            # there is nothing on any other interface to allow or deny. The
            # firewall is now the second line rather than the only one.
            #
            # What IS exposed on the tailnet is caddy's 443, and the same
            # reasoning applies to it one file over: `trustedInterfaces =
            # [ "tailscale0" ]` lets tailnet traffic bypass the allow-list
            # while everything on any other interface hits the default-deny.
            # See reverse-proxy/caddy.nix for that half.
            #
            # Caveat worth keeping in view, unchanged by any of the above:
            # trustedInterfaces trusts the WHOLE interface, not a port -- it
            # is "anything arriving over Tailscale is already trusted", the
            # same blanket trust ssh/kde-connect/etc. get on this host. That
            # is the existing security model here, not something this module
            # introduces. And per networking/tailscale.nix's own "TWO REAL
            # TRAPS" note: a tailnet ACL denying member-to-member traffic
            # would make this unreachable even though every setting in this
            # repo is correct -- that's fixed in Tailscale's admin console,
            # not here.
        };
}

# ── history ─────────────────────────────────────────────────────────────────
#
# 2026-08-24 — this used to bind 0.0.0.0, and `root_url` used to be unset
#
# From 2026-08-23 until 2026-08-24 `settings.server.http_addr` was "0.0.0.0",
# with this comment on it:
#
#   > 0.0.0.0, not the loopback-only pattern the rest of this stack uses:
#   > this is the one service here that has to be reachable from off-host
#   > (over Tailscale) at all, so it can't bind to 127.0.0.1 the way
#   > node-exporter/cadvisor/libvirt-exporter/prometheus itself do.
#   > "Tailnet only" is enforced below, at the firewall, not here.
#
# True at the time: nothing else on this host could accept the connection, so
# Grafana had to take it itself, and `trustedInterfaces = [ "tailscale0" ]`
# was the ONLY thing between port 3000 and the LAN. Adding
# nire/reverse-proxy/caddy.nix removed that constraint -- caddy accepts on
# the tailnet, terminates TLS with a cert from tailscaled, and connects to
# this port over loopback -- so the listener moved back in line with the rest
# of the stack.
#
# The same comment ended by predicting the other half of this change:
#
#   > If Grafana ever throws "invalid redirect" errors after login, that's
#   > `domain`/`root_url` needing to be set to this host's MagicDNS name
#   > (`ts-cube` ... NOT `nire-cube`); left at the module defaults for now
#   > since nothing has hit that yet.
#
# `root_url` is set now, and for the predicted reason plus one more: behind a
# path prefix Grafana needs both `root_url` AND `serve_from_sub_path`, and
# the FQDN in it has to be the full `ts-cube.moose-micro.ts.net`, not the
# short MagicDNS name that comment guessed at, because it is what the browser
# will have in its address bar.
