{ config, ... }:
{
    flake.modules.homeManager.pkgs-gui.imports = [ config.flake.modules.homeManager.obsidian ];

    flake.modules.homeManager.obsidian =
# Obsidian - markdown PKM like org mode, https://obsidian.md/
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        obsidian
    ];
}
;}
