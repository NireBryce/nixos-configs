{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        # TODO: these modules should be stored outside of the users folder, so it's clearer when it's imported
        flake.modules.nixos.${moduleName} = {
            users.mutableUsers = false;
            users.users = { 
                # groups = {
                #     elly = { };
                # };
                elly = {
                    # group = "elly";
                    # shell = lib.mkDefault pkgs.bash;
                    isNormalUser = true;
                    extraGroups = [ "wheel" "audio" "podman" ]; # Enable ‘sudo’ and deeper audio access
                    hashedPasswordFile = "/persist/passwords/elly";
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

        flake.modules.darwin.${moduleName} = {
            fonts.packages = with pkgs; [
                nerd-fonts.fira-code
                nerd-fonts.iosevka
                nerd-fonts.jetbrains-mono
            ];
        };
    };
}
