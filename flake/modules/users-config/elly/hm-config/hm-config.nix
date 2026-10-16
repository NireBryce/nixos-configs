# Module file: named after this file; why it looks this way: wiki/module-files.md
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
