{ config, ... }:
{
    flake.modules.homeManager.pkgs-gui.imports = [ config.flake.modules.homeManager.bitwarden ];

    flake.modules.homeManager.bitwarden =
# bitwarden - password manager https://bitwarden.com/";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        bitwarden-desktop
    ];
}
;}
