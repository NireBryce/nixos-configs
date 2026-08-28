# prometheus-libvirt-exporter: per-VM state/CPU/memory/disk/network metrics
# for whatever libvirt/QEMU guests are defined on this host via
# `virtualization`. No guest is currently defined here -- `virtualization-cube`
# (nire-llm-sandbox) was removed 2026-08-28 -- so this scrapes an empty set
# until a VM exists again; kept rather than dropped since the exporter itself
# is generic to the `virtualization` category, not to that one VM. One of
# three things prometheus.nix scrapes -- see that file and grafana.nix for
# the rest of the stack this belongs to.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            # # description = "prometheus-libvirt-exporter -- per-VM metrics for prometheus.nix to scrape";
            services.prometheus.exporters.libvirt = {
                enable = true;

                # libvirtUri defaults to qemu:///system already -- the same
                # connection libvirt.nix points virt-manager at, so this needs
                # no override to reach the VMs this host actually runs.

                # The exporter's own default group is a dedicated
                # `libvirt-exporter` group with no access to libvirtd's socket
                # (/run/libvirt/libvirt-sock, group `libvirtd`, mode 0770).
                # Without this it starts and serves an empty metrics page
                # rather than failing loudly -- same shape as the elly-needs-
                # libvirtd-group note in libvirt.nix, for the same socket.
                group = "libvirtd";

                listenAddress = "127.0.0.1"; # loopback-only, same reasoning as
                                              # node-exporter.nix: prometheus.nix
                                              # scrapes it locally, nothing else
                                              # needs to reach it directly.
            };
        };
}
