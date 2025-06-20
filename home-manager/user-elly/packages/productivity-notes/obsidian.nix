# desc = "Obsidian markdown PKM like org mode, https://obsidian.md/";
{ pkgs, ... }:
let
    packageList = with pkgs; [
        obsidian
    ];
in 
{
    home.packages = packageList;
}
