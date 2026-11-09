# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki

# summary: Prometheus itself: scrapes the four loopback-only exporters
# (node-exporter.nix, cadvisor.nix, libvirt-exporter.nix, smartctl-exporter.nix)
# and the QNAP through snmp-exporter.nix, stores the time series
# grafana.nix's dashboard reads from, and hands rule alerts to
# alertmanager.nix.
{
    nixos = { config, ... }:
    let
        # Targets are read from the exporters' own port options, so a port
        # changed in an exporter module moves the scrape with it. The
        # exporters are loopback-only (their modules say why), hence the
        # fixed host.
        loopback = "127.0.0.1";
        exporters = config.services.prometheus.exporters;
    in {
        services.prometheus = {
            enable = true;

            # 127.0.0.1, not the default 0.0.0.0: nothing outside this host
            # queries Prometheus directly, Grafana does over loopback via
            # the datasource grafana.nix provisions. Same "only grafana.nix
            # is meant to be reachable off-host" reasoning as the exporters.
            listenAddress = "127.0.0.1";

            # Defaults (2s retention... no -- retentionTime defaults to 15d)
            # are fine for a single homelab host's worth of series; not
            # overridden here.

            alertmanagers = [ {
                static_configs = [ { targets = [ "${config.services.prometheus.alertmanager.listenAddress}:${toString config.services.prometheus.alertmanager.port}" ]; } ]; # alertmanager.nix
            } ];

            scrapeConfigs = [
                {
                    job_name        = "node";
                    static_configs  = [ { targets = [ "${loopback}:${toString exporters.node.port}" ]; } ]; # node-exporter.nix
                }
                {
                    job_name        = "cadvisor";
                    static_configs  = [ { targets = [ "${loopback}:${toString config.services.cadvisor.port}" ]; } ]; # cadvisor.nix
                }
                {
                    job_name        = "libvirt";
                    static_configs  = [ { targets = [ "${loopback}:${toString exporters.libvirt.port}" ]; } ]; # libvirt-exporter.nix
                }
                {
                    job_name        = "smartctl";
                    static_configs  = [ { targets = [ "${loopback}:${toString exporters.smartctl.port}" ]; } ]; # smartctl-exporter.nix
                }
                {
                    # The SNMP exporter's multi-target pattern: Prometheus
                    # asks the local exporter to poll the NAS. The NAS name
                    # becomes the `instance` label; the scrape itself goes
                    # to the exporter on loopback.
                    job_name        = "qnap";
                    metrics_path    = "/snmp";
                    params          = { module = [ "qnap" ]; auth = [ "qnap_v3" ]; };
                    static_configs  = [ { targets = [ "ts-hive" ]; } ];
                    scrape_interval = "1m";
                    scrape_timeout  = "30s";
                    relabel_configs = [
                        { source_labels = [ "__address__" ]; target_label = "__param_target"; }
                        { source_labels = [ "__param_target" ]; target_label = "instance"; }
                        { target_label = "__address__"; replacement = "${loopback}:${toString exporters.snmp.port}"; } # snmp-exporter.nix
                    ];
                }
            ];
        };
    };
}
