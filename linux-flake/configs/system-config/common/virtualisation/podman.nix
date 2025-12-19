{ pkgs, ... }:
let
    packageList = with pkgs; [ 
        host-spawn
        podman-compose
    ];

in
    {
        virtualisation.podman = {
            enable = true;
            dockerCompat = true;
            defaultNetwork.settings.dns_enabled = true; # Required for containers under podman-compose to be able to talk to each other.
        };

        virtualisation.oci-containers.backend = "podman";

        users.groups.container = {};
        users.users.container = {
            isNormalUser = true;
            group = "container";
            home = "/var/lib/container";
            linger = true;
            createHome = true;
            autoSubUidGidRange = true;
        };

        users.users.elly = { 
            # credit: https://github.com/NixOS/nixpkgs/issues/389088#issuecomment-3379482882
            subUidRanges = [ { startUid = 100000; count = 65536; } ];
            subGidRanges = [ { startGid = 100000; count = 65536; } ];

            extraGroups = [
                "podman"
            ];
        };

        # vscode devcontainers https://wiki.nixos.org/wiki/Podman
        # Global `/etc/containers/registries.conf`
        environment.etc."containers/registries.conf".text = ''
            [registries.search]
            registries = ['docker.io']
        '';

        # User-scoped `~/.config/containers/registries`
        xdg.configFile."containers/registries.conf".text = ''
            [registries.search]
            registries = ['docker.io']
        '';


        environment.systemPackages = packageList;

    }

