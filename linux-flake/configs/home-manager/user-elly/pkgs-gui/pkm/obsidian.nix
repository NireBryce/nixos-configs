# Obsidian - markdown PKM like org mode, https://obsidian.md/
{ den.aspects.hm.provides.pkgs-gui = 
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
