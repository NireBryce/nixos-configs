# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
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
