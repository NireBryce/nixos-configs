# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki

# summary: Prometheus itself: scrapes the four loopback-only exporters
# (node-exporter.nix, cadvisor.nix, libvirt-exporter.nix, smartctl-exporter.nix)
# and stores the time series grafana.nix's dashboard reads from.
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
            ];
        };
    };
}
