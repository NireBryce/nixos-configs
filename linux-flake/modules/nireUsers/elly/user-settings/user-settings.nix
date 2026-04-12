{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName} = { 
        nixos = {
            users.mutableUsers = false;
            users.users = { 
                # groups = {
                #     elly = { };
                # };
                elly = {
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
        };
    
    
        homeManager = {
            home.stateVersion   = "22.11";
            home.username       = "elly";
            home.homeDirectory  = lib.mkDefault "/home/elly";
        };

        darwin = { pkgs, ... }: {
            fonts.packages = with pkgs; [
                nerd-fonts.fira-code
                nerd-fonts.iosevka
                nerd-fonts.jetbrains-mono
            ];
        };
    };
}
