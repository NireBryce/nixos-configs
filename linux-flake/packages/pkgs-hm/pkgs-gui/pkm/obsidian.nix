# Obsidian - markdown PKM like org mode, https://obsidian.md/
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        obsidian
    ];
}
