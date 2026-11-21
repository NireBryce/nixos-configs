# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki

# summary: node_exporter: CPU/memory/disk/network metrics for the host itself.
# One of the things prometheus.nix scrapes -- see that file and grafana.nix
# for the rest of the stack this belongs to. Also owns the textfile collector
# directory that other modules publish metrics into (runner-alerts.nix,
# actions-runner.nix, restic.nix's backupPrepareCommand).
let
    # Each writer (the three named above) repeats this string; keep them
    # equal. The collector is on by default but reads nothing without a
    # directory.
    textfileDir = "/var/lib/node-exporter-textfile";
in {
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

            extraFlags = [ "--collector.textfile.directory=${textfileDir}" ];
        };

        # Written by root (timers, the backup prepare step, the runner cycle);
        # read by node-exporter, which runs as its own user, so 0755.
        systemd.tmpfiles.rules = [ "d ${textfileDir} 0755 root root -" ];
    };
}
