# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki

# summary: node_exporter: CPU/memory/disk/network metrics for the host itself.
# One of three things prometheus.nix scrapes -- see that file and grafana.nix
# for the rest of the stack this belongs to.
{
    nixos = {
        services.prometheus.exporters.node = {
            enable = true;

            # 127.0.0.1, not the default 0.0.0.0: prometheus.nix scrapes this
            # over loopback, and nothing outside this host -- not even over
            # tailscale0 -- needs to reach it directly. grafana.nix is the one
            # thing in this stack that is actually meant to be reachable
            # off-host; everything upstream of it (this, cadvisor.nix,
            # libvirt-exporter.nix, prometheus.nix itself) stays on loopback.
            # Port is left at its default (9100) -- prometheus.nix's scrape
            # config assumes that default rather than restating it here.
            listenAddress = "127.0.0.1";
        };
    };
}
