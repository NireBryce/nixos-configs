{ config, ... }:
{
    flake.modules.homeManager.ellyHomeManager.imports = [ config.flake.modules.homeManager.elly-hm-settings ];

    flake.modules.homeManager.elly-hm-settings = 
{
    home.stateVersion   = "22.11";
    home.username       = "elly";
    home.homeDirectory  = "/home/elly";
}
;}
