# Obsidian - markdown PKM like org mode, https://obsidian.md/
{ den.aspects.pkgs-gui.homeManager = 
{ pkgs, ... }:
let
    packageList = with pkgs; [
        obsidian
    ];
in 
{
    home.packages = packageList;
}
;}
