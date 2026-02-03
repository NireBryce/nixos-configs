# Obsidian - markdown PKM like org mode, https://obsidian.md/
{ flake.modules.homeManager.packages.productivity.obsidian =
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
