{
    lib,
    config,
    pkgs,
    ...
}:
let
    enabled = builtins.elem "userElly" (config.my.roles or []);
in
{
    flake.modules.nixos.user-list.elly = { ... }: {
        config = lib.mkIf enabled {
            users.mutableUsers = false;
            users.users = { 
                elly = {
                    shell                 = pkgs.bash;
                    isNormalUser          = true;
                    extraGroups           = [ "wheel" "audio" "podman" ]; # Enable ‘sudo’ and deeper audio access
                    hashedPasswordFile    = "/persist/passwords/elly";
                    packages  = with pkgs; [ 
                        # Emergency packages if home-manager dies
                        firefox
                        git
                        gh
                        micro
                        tree
                        kdePackages.partitionmanager
                    ];
                };
            };
        };
    };
}
