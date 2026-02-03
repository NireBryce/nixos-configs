# cht.sh - cli cheatsheets
{ flake.modules.homeManager.shellUtil.helpSystems.cheat =
{ pkgs, ... }:
let packageList = with pkgs; [
    cheat
];
in
{
    home.packages = packageList;
}
;}
