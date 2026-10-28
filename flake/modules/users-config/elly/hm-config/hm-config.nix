# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{ lib, ... }:
{
    homeManager = {
        home = {
            stateVersion   = lib.mkDefault "22.11";
            username       = lib.mkDefault "elly";
            homeDirectory  = lib.mkDefault "/home/elly"; # Darwin is different
        };
    };
}
