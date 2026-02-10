# Obsidian - markdown PKM like org mode, https://obsidian.md/
{ den.bundles.hm.obsidian =
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
