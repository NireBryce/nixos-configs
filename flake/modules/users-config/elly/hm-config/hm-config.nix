# dirs-as-categories: the module is named after this file; its categories are the folders above it
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
