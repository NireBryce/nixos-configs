{ config, ... }:
{
    flake.modules.homeManager.pkgs-gui.imports = [ config.flake.modules.homeManager.libre-office ];

    flake.modules.homeManager.libre-office =
# libreoffice - office productivity software https://www.libreoffice.org/
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        libreoffice-qt
    ];
}
;}
