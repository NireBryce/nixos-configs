# TODO: merge this and durandal into one config, split out hardware-specific.
#* This defines the nire-durandal host-specific user config for elly
{ 
  self,
  pkgs,
  ... 
}:

let 
    flakePath       =       self; # the root of the flake
    ellyPath        =       "${flakePath}/home-manager/user-elly";
    
    # todo: experimenting with uing variable names to better explain unintuitive nixOS names
    subConfigList = [ 
        "${ellyPath}/nix-settings"
        "${ellyPath}/dotfiles"
        "${ellyPath}/git"
        "${ellyPath}/shell"
        "${ellyPath}/window-manager/_kde.nix"

        #todo: folderize and default
        "${ellyPath}/packages/_general-cli-pkgs.nix"
        "${ellyPath}/packages/_dev-pkgs.nix"
        "${ellyPath}/packages/_linux-cli-pkgs.nix"
        "${ellyPath}/packages/_linux-gui-pkgs.nix"
        "${flakePath}/home-manager/plasma-manager"
    ];

in {
    imports = subConfigList;

    home.username            = "elly";
    home.homeDirectory       = "/home/elly";

    home.stateVersion        = "22.11"; # Do not edit. To figure this out (in-case it changes) you can comment out the line and see what version it expected.

    home.packages = with pkgs; [
        google-chrome
    ];
} 

# REMINDER: home manager broke, so I had to use `nix-shell -p home-manager` to bootstrap
