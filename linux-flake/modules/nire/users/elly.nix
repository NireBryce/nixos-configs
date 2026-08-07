{ config, ... }:
{
    flake.modules.nixos.base.imports = [ config.flake.modules.nixos.elly ];

    flake.modules.nixos.elly =
{ config, pkgs, ... }:
{
    users.mutableUsers = false;
    users.users = {
        # groups = {
        #     elly = { };
        # };
        ${config.nire.primaryUser} = {
            # group = "elly";
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
}
;}
