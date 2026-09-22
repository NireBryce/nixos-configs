# smartctl_exporter: per-disk SMART/NVMe wear metrics (health status,
# percentage used, media errors, temperature) for prometheus.nix to scrape
# and grafana.nix to trend over time -- the one piece of this stack that
# tracks wear rather than a moment-in-time reading, unlike the CLI tools
# (smartd.nix, nvme-cli.nix) which only show current state.
#
# No Grafana panel added alongside this yet: the exporter's exact metric
# names (`smartctl_device_*`) weren't confirmed against this host's own
# `/metrics` output before landing this, and this stack's own convention
# (see grafana.nix's dashboards) is to build panels off queries actually run
# against real data, not off documentation. Check
# `curl -s 127.0.0.1:9633/metrics | grep smartctl_device` on nire-cube once
# this is deployed, then add a "Storage" row to
# grafana/_dashboards/nire-cube-overview.json the same way
# libvirt-exporter.nix's metrics became the "libvirt / QEMU VMs" row.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            # # description = "smartctl_exporter -- per-disk SMART/wear metrics for prometheus.nix to scrape";
            services.prometheus.exporters.smartctl = {
                enable = true;

                # 127.0.0.1, not the default 0.0.0.0 -- same "only grafana.nix
                # is meant to be reachable off-host" reasoning as
                # node-exporter.nix/cadvisor.nix/libvirt-exporter.nix.
                listenAddress = "127.0.0.1";

                # devices left at [] (default): autodiscovers every SMART/NVMe
                # capable block device rather than naming cube's disks by path.
            };
        };
}
