{ config, ... }:
{
    flake.modules.homeManager.pkgs-linux-utils.imports = [ config.flake.modules.homeManager.ipcalc ];

    flake.modules.homeManager.ipcalc =
# desc = "IP address calculator https://gitlab.com/ipcalc/ipcalc";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        ipcalc
    ];
}
;}
