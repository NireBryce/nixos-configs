# Grafana: the one piece of this stack (prometheus.nix, node-exporter.nix,
# cadvisor.nix, libvirt-exporter.nix) meant to be reached off-host, and then
# only over the tailnet -- see the firewall comment below before assuming
# `openFirewall`-style options belong here.
#
# RUNTIME-VERIFIED, 2026-08-23, on nire-cube: `just switch` activates cleanly
# and every other unit in this stack came up, but grafana.service itself
# failed on the first real switch -- the secret_key file existed but was
# root:root, unreadable to the `grafana` user the service runs as. See the
# `warnings` entry below for the fix and the corrected creation command.
# Nothing else in this module has been checked against real hardware yet.
#
# No `grafana-persist.nix` alongside this the way tailscale.nix has
# tailscale-persist.nix: cube-configuration.nix's own header says this host
# was installed with a plain persistent root, not the `/root` wipe
# durandal/tenacity/lego get, so /var/lib/grafana (sqlite db, provisioned
# dashboards land here as read-only file-provider entries, not writes) just
# survives reboots with no environment.persistence entry needed. If this
# module is ever imported by a host that DOES wipe root, add one first,
# modeled on tailscale-persist.nix -- otherwise every dashboard edit made
# through the UI (anything not sourced from _dashboards/) is gone on reboot.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);

        # Fixed rather than left to auto-generate, so the dashboard JSON below
        # can reference it directly instead of needing a templated
        # `${DS_PROMETHEUS}` variable resolved through Grafana's import flow --
        # this datasource and that dashboard are both provisioned from files by
        # the same module, so nothing needs resolving at import time.
        prometheusDatasourceUid = "prometheus-cube";
    in {
        flake.modules.nixos.${moduleName} = {
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
                # to exist). It DOES need to exist at service-start time
                # though, and nothing in this repo creates it -- same shape as
                # elly's hashedPasswordFile
                # (nireUser/elly/user-settings/WARN-password-required.nix),
                # hence the matching `warnings` entry below rather than
                # silently shipping a build that fails at boot.
                settings.security.secret_key = "$__file{/persist/secrets/grafana-secret-key}";

                settings.server = {
                    http_port = 3000;

                    # 0.0.0.0, not the loopback-only pattern the rest of this
                    # stack uses: this is the one service here that has to be
                    # reachable from off-host (over Tailscale) at all, so it
                    # can't bind to 127.0.0.1 the way node-exporter/cadvisor/
                    # libvirt-exporter/prometheus itself do.
                    #
                    # "Tailnet only" is enforced below, at the firewall, not
                    # here -- see that comment for the actual mechanism and its
                    # caveats. If Grafana ever throws "invalid redirect"
                    # errors after login, that's `domain`/`root_url` needing to
                    # be set to this host's MagicDNS name (`ts-cube`, per
                    # networking/tailscale.nix's header -- NOT `nire-cube`,
                    # that name was the costly-to-rediscover trap that file
                    # documents); left at the module defaults for now since
                    # nothing has hit that yet.
                    http_addr = "0.0.0.0";
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

            # Same pattern as WARN-password-required.nix: this repo declares
            # the option, it does not create the file the option reads at
            # runtime. Unconditional (not gated on impermanence the way that
            # file is) because `monitoring` is only imported by cube today,
            # and cube always needs this regardless of its persistence model.
            warnings = [
                ''
                    Grafana's secret_key has no value here until you create
                    /persist/secrets/grafana-secret-key by hand -- nothing in
                    this repo does it for you, and Grafana will fail to start
                    without it.

                    RUNTIME-VERIFIED TRAP, 2026-08-23: the file has to be
                    owned by the `grafana` user, not root. `services.grafana`
                    runs its systemd unit as `User = "grafana"` (upstream
                    nixpkgs grafana.nix), and a file created the obvious way
                    -- `sudo install -m600 ...`, root:root -- is unreadable to
                    that user. Grafana starts, can't read its own secret_key,
                    and dies; `systemctl status grafana` shows the service
                    failed with nothing more specific than that in the
                    default log view. This is why the fix below is two steps,
                    not one, and why the `grafana` user has to already exist
                    (i.e. a `switch` with this module has already run once)
                    before the chown can succeed:

                        sudo install -D -m600 /dev/stdin /persist/secrets/grafana-secret-key <<< "$(openssl rand -hex 32)"
                        sudo chown grafana:grafana /persist/secrets/grafana-secret-key

                    (`/dev/stdin` here, not `<(openssl rand -hex 32)` as a bare
                    argument -- process substitution's /dev/fd/N path doesn't
                    reliably survive being handed to a forked `sudo` child on
                    every shell, and hit exactly that "cannot stat" failure
                    here. A here-string into /dev/stdin does not have that
                    problem: sudo inherits stdin directly.)

                    If the file already exists with the wrong ownership from
                    before this warning was corrected, `sudo chown
                    grafana:grafana` on it and `sudo systemctl restart
                    grafana` is enough -- no need to regenerate the key.
                ''
            ];

            # DELIBERATELY NOT adding 3000 to networking.firewall.allowedTCPPorts
            # (networking.nix, part of the `system` category this host already
            # imports). allowedTCPPorts opens a port on every interface; what
            # actually makes Grafana tailnet-only is `trustedInterfaces =
            # [ "tailscale0" ]`, already set in that same file -- traffic
            # arriving on tailscale0 bypasses the allow-list entirely, traffic
            # arriving on any other interface hits the default-deny and is
            # dropped, so leaving port 3000 out of the list is what keeps this
            # off the LAN. Same mechanism CLAUDE.md's tailscale.nix section
            # already documents (`services.tailscale.openFirewall` +
            # `trustedInterfaces`), applied to a second service.
            #
            # Caveat worth keeping in view: trustedInterfaces trusts the WHOLE
            # interface, not just this port -- it is not a Grafana-specific
            # rule, it is "anything arriving over Tailscale is already
            # trusted", the same blanket trust ssh/kde-connect/etc. get on this
            # host. That is the existing security model here, not something
            # this module introduces. And per networking/tailscale.nix's own
            # "TWO REAL TRAPS" note: a tailnet ACL denying member-to-member
            # traffic would make this unreachable even though every setting in
            # this repo is correct -- that's fixed in Tailscale's admin
            # console, not here.
        };
}
