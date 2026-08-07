{ config, ... }:
{
    flake.modules.homeManager.pkgs-gui.imports = [ config.flake.modules.homeManager.discord ];

    flake.modules.homeManager.discord =
# discord gamer chat app that broke containment
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        discord
    ];
}
;}
