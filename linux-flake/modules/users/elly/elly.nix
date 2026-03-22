{ self, inputs, ...}:
{ flake.homeModules.elly =
{ pkgs, ... }:
{
    imports = with self.homeModules; [ 
        elly-aliases
        elly-fonts
        elly-git
        elly-hm-settings
        elly-home-config
        elly-nix-settings
        elly-shell-bash
        elly-shell-fish
        elly-shell-zsh
        pkgs-linux-utils
        pkgs-gui
        pkgs-cli
    ];
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
}
;}
