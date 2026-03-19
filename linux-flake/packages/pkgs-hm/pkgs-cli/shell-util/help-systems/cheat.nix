# cht.sh - cli cheatsheets
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        cheat
    ];
}
