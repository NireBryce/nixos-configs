{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
        textfileDir = "/var/lib/node-exporter-textfile";
    in {
        flake.modules.nixos.${moduleName} = { pkgs, config, ... }: let
            promUid = (lib.findFirst (d: d.type == "prometheus") null
                config.services.grafana.provision.datasources.settings.datasources).uid;

            # Egress drop counters from vm-networking.nix's `cube-vm-egress`
            # (counters, reset by a firewall reload -- `increase()` copes),
            # and refused lookups from vm-egress-dns.nix's query log over
            # the last five minutes.
            egressMetrics = pkgs.writeShellScript "forge-runner-egress-metrics" ''
                set -euo pipefail
                PATH=${lib.makeBinPath [ config.networking.firewall.package pkgs.gawk pkgs.gnugrep pkgs.coreutils pkgs.systemd ]}
                rules=$(iptables -w -t mangle -L cube-vm-egress -vxn 2>/dev/null || true)
                private=$(printf '%s\n' "$rules" | awk '$3 == "DROP" && !/match-set/ { s += $1 } END { print s + 0 }')
                allow=$(printf '%s\n' "$rules" | awk '$3 == "DROP" && /match-set/ { s += $1 } END { print s + 0 }')
                refused=$(journalctl -u vm-egress-dns --since "-5 min" -o cat --no-pager 2>/dev/null | grep -c ' is NXDOMAIN$' || true)
                tmp=${textfileDir}/.forge_runner_egress.prom.tmp
                {
                    echo "# HELP forge_runner_egress_dropped_packets_total Guest packets dropped by cube-vm-egress."
                    echo "# TYPE forge_runner_egress_dropped_packets_total counter"
                    echo "forge_runner_egress_dropped_packets_total{reason=\"private_range\"} $private"
                    echo "forge_runner_egress_dropped_packets_total{reason=\"not_allowlisted\"} $allow"
                    echo "# HELP forge_runner_dns_refused_5m Guest DNS lookups refused by vm-egress-dns in the last 5 minutes."
                    echo "# TYPE forge_runner_dns_refused_5m gauge"
                    echo "forge_runner_dns_refused_5m $refused"
                } > "$tmp"
                chmod 0644 "$tmp"
                mv -f "$tmp" ${textfileDir}/forge_runner_egress.prom
            '';

            # One Grafana rule: query A (instant), reduce B to its last
            # value, threshold C on B.
            rule = { uid, title, expr, op, threshold, for ? "0s", noData ? "OK", summary, description }: {
                inherit uid title for;
                condition    = "C";
                noDataState  = noData;
                execErrState = "Error";
                labels       = { area = "forge-runner"; };
                annotations  = { inherit summary description; };
                data = [
                    {
                        refId = "A";
                        relativeTimeRange = { from = 600; to = 0; };
                        datasourceUid = promUid;
                        model = { refId = "A"; inherit expr; instant = true; intervalMs = 60000; maxDataPoints = 43200; };
                    }
                    {
                        refId = "B";
                        datasourceUid = "__expr__";
                        model = { refId = "B"; type = "reduce"; expression = "A"; reducer = "last"; };
                    }
                    {
                        refId = "C";
                        datasourceUid = "__expr__";
                        model = {
                            refId = "C"; type = "threshold"; expression = "B";
                            conditions = [ { evaluator = { type = op; params = [ threshold ]; }; } ];
                        };
                    }
                ];
            };
        in {
            # # description = "metrics and Grafana alert rules for the Forgejo runner VM";


            services.prometheus.exporters.node = {
                enabledCollectors = [ "systemd" ];
                extraFlags = [
                    "--collector.textfile.directory=${textfileDir}"
                    # Only the units the rules below watch; the collector
                    # otherwise exports every unit on the host.
                    "--collector.systemd.unit-include=(forge-runner-cycle|vm-egress-dns|libvirt-vm-forge-runner)[.]service"
                ];
            };

            systemd = {
                # Written by root (the timer below, and actions-runner.nix's
                # cycle); read by node-exporter, which runs as its own user.
                tmpfiles.rules = [ "d ${textfileDir} 0755 root root -" ];

                services.forge-runner-egress-metrics = {
                    description = "Write forge-runner egress metrics for node-exporter";
                    serviceConfig = { Type = "oneshot"; ExecStart = egressMetrics; };
                };
                timers.forge-runner-egress-metrics = {
                    wantedBy    = [ "timers.target" ];
                    timerConfig = { OnBootSec = "1min"; OnUnitActiveSec = "1min"; };
                };
            };

            # Evaluated by Grafana itself (no Alertmanager); state shows
            # under Alerting -> Alert rules, folder "forge-runner". Where
            # notifications go is Grafana's contact points / policy.
            services.grafana.provision.alerting.rules.settings = {
                apiVersion = 1;
                groups = [ {
                    orgId    = 1;
                    name     = "forge-runner";
                    folder   = "forge-runner";
                    interval = "1m";
                    rules = [
                        (rule {
                            uid = "forge-runner-egress-not-allowlisted";
                            title = "Runner guest: connection outside the egress allowlist";
                            expr = ''sum(increase(forge_runner_egress_dropped_packets_total{reason="not_allowlisted"}[10m]))'';
                            op = "gt"; threshold = 0;
                            summary = "A runner job tried to reach an address it wasn't given by the allowlisting resolver.";
                            description = "Usually a hard-coded IP or a domain missing from vm-egress-dns.nix's allowedDomains. See journalctl -u forge-runner-cycle for the job's time window.";
                        })
                        (rule {
                            uid = "forge-runner-egress-private";
                            title = "Runner guest: connection to a private or tailnet range";
                            expr = ''sum(increase(forge_runner_egress_dropped_packets_total{reason="private_range"}[10m]))'';
                            op = "gt"; threshold = 0;
                            summary = "A runner job tried to reach the LAN or the tailnet; cube dropped it.";
                            description = "No legitimate job does this. Check which workflow ran then (repo Actions tab).";
                        })
                        (rule {
                            uid = "forge-runner-dns-refused";
                            title = "Runner guest: DNS lookups refused";
                            expr = "max_over_time(forge_runner_dns_refused_5m[10m])";
                            op = "gt"; threshold = 0;
                            summary = "A runner job looked up a name outside the allowlist.";
                            description = "The names are in journalctl -u vm-egress-dns (\"config <name> is NXDOMAIN\"). Add a domain to vm-egress-dns.nix's allowedDomains if a job legitimately needs it.";
                        })
                        (rule {
                            uid = "forge-runner-boot-loop";
                            title = "Runner guest: failing to start";
                            expr = "forge_runner_short_cycle_streak";
                            op = "gt"; threshold = 1;
                            summary = "Two or more runner cycles in a row ended within two minutes -- the guest is probably dying at boot.";
                            description = "Check journalctl -u forge-runner-cycle, then ssh forge-runner on cube or sudo virsh console forge-runner.";
                        })
                        (rule {
                            uid = "forge-runner-units-down";
                            title = "Runner: cycle or allowlist resolver not running";
                            expr = ''min(node_systemd_unit_state{name=~"forge-runner-cycle.service|vm-egress-dns.service",state="active"})'';
                            op = "lt"; threshold = 1;
                            for = "5m"; noData = "Alerting";
                            summary = "forge-runner-cycle or vm-egress-dns has not been active for 5 minutes.";
                            description = "systemctl status forge-runner-cycle vm-egress-dns on cube.";
                        })
                    ];
                  }
                  # Host-wide, but here because the likeliest filler is the
                  # forge: Actions artifacts and logs land in
                  # /var/lib/forgejo on cube's root filesystem (forgejo.nix
                  # caps them with a quota and retention).
                  {
                    orgId    = 1;
                    name     = "cube";
                    folder   = "cube";
                    interval = "5m";
                    rules = [
                        (rule {
                            uid = "cube-root-disk-low";
                            title = "cube: root filesystem under 10% free";
                            expr = ''min(node_filesystem_avail_bytes{mountpoint="/",fstype!="tmpfs"} / node_filesystem_size_bytes{mountpoint="/",fstype!="tmpfs"})'';
                            op = "lt"; threshold = 0.10;
                            for = "15m"; noData = "Alerting";
                            summary = "cube's / has less than 10% free.";
                            description = "Check du -sh /var/lib/forgejo /var/lib/libvirt/images /nix/store on cube; nix-collect-garbage if the store is the cause.";
                        })
                    ];
                } ];
            };
        };
}
