# Prometheus itself: scrapes the three loopback-only exporters
# (node-exporter.nix, cadvisor.nix, libvirt-exporter.nix) and stores the time
# series grafana.nix's dashboard reads from.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            # # description = "prometheus -- scrapes the exporters, stores metrics for grafana.nix";
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
                        static_configs  = [ { targets = [ "127.0.0.1:9100" ]; } ]; # node-exporter.nix's default port
                    }
                    {
                        job_name        = "cadvisor";
                        static_configs  = [ { targets = [ "127.0.0.1:8080" ]; } ]; # cadvisor.nix
                    }
                    {
                        job_name        = "libvirt";
                        static_configs  = [ { targets = [ "127.0.0.1:9177" ]; } ]; # libvirt-exporter.nix's default port
                    }
                ];
            };
        };
}
