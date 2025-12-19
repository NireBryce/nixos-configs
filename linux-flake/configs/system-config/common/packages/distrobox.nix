{ pkgs, ... }:
{
    virtualisation.podman = {
        enable = true;
        dockerCompat = true;
        defaultNetwork.settings.dns_enabled = true; # Required for containers under podman-compose to be able to talk to each other.
    };


    environment.systemPackages = with pkgs; [ 
        distrobox
        distrobox-tui
        distroshelf
        boxbuddy
        host-spawn
    ];

    # expose profile to distrobox containers
    environment.etc."distrobox/distrobox.conf".text = ''
        container_additional_volumes="/nix/store:/nix/store:ro /etc/profiles/per-user:/etc/profiles/per-user:ro /etc/static/profiles/per-user:/etc/static/profiles/per-user:ro"
    '';

}

