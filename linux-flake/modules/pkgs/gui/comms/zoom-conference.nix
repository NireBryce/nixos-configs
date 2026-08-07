{ config, ... }:
{
    flake.modules.homeManager.pkgs-gui.imports = [ config.flake.modules.homeManager.zoom-conference ];

    flake.modules.homeManager.zoom-conference =
# zoom videoconferencing software
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        zoom-us
    ];
}
;}
