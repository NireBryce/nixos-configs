# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki

# summary: cadvisor: per-container CPU/memory/network metrics, for the podman
# containers containers.nix's `podman` category enables. One of three things
# prometheus.nix scrapes -- see that file and grafana.nix for the rest of the
# stack this belongs to.
{
    nixos = {
        services.cadvisor = {
            enable        = true;
            listenAddress = "127.0.0.1"; # already the default; stated because
                                          # prometheus.nix's scrape config
                                          # depends on it not moving.
            port          = 8080;        # also the default, same reason.
        };

        # NOT runtime-verified against podman specifically, as of writing --
        # cadvisor's own `after = [ ... "docker.service" ... ]` (upstream
        # nixpkgs module) is ordering, not a hard dependency, and this host
        # runs podman, not docker. cadvisor falls back to walking cgroups
        # directly when it has no docker/containerd socket to query, which
        # is expected to surface podman's containers too, just labelled by
        # raw cgroup path rather than image/container name. If that turns
        # out too coarse once something is actually running in a container
        # on this host, `virtualisation.podman.dockerSocket.enable` (podman's
        # own docker-API-compatible socket) plus
        # `services.cadvisor.extraOptions = [ "--docker=unix:///run/podman/podman.sock" ]`
        # is the documented way to give cadvisor real container names --
        # not added here since nothing has confirmed it's needed yet.
    };
}
