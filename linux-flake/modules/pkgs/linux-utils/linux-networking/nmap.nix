{ config, ... }:
{
    flake.modules.homeManager.pkgs-linux-utils.imports = [ config.flake.modules.homeManager.nmap ];

    flake.modules.homeManager.nmap =
# desc = "network scanner http://www.nmap.org/";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        nmap
    ];
}
;}
