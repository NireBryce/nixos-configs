# TODO: merge this and durandal into one config, split out hardware-specific.
#* This defines the nire-durandal host-specific user config for elly
{ 
  self,
  ... 
}:

let 
    flakePath       =       self; # the root of the flake
    ellyPath        =       "${flakePath}/home-manager/user-elly";
    
    subConfigList = [ 
        "${ellyPath}/dotfiles"
        "${ellyPath}/git"
        "${ellyPath}/packages/_general-cli-pkgs.nix"
        "${ellyPath}/packages/_dev-pkgs.nix"
        "${ellyPath}/packages/_linux-cli-pkgs.nix"
        "${ellyPath}/packages/_linux-gui-pkgs.nix"
        "${ellyPath}/shell"
        "${ellyPath}/window-manager/_kde.nix"
    ];

in {
    imports = subConfigList;


  ## Defaults
    nixpkgs.config = {
        allowUnfree          =     true;            # Disable if you don't want unfree packages
        allowUnfreePredicate = (_: true);           # Workaround for https://github.com/nix-community/home-manager/issues/2942
    };
    home.username            = "elly";
    home.homeDirectory       = "/home/elly";

    home.stateVersion        = "22.11"; # Do not edit. To figure this out (in-case it changes) you can comment out the line and see what version it expected.
} 

# REMINDER: home manager broke, so I had to use `nix-shell -p home-manager` to bootstrap
