# cht.sh - cli cheatsheets
{ den.bundles.hm.shell-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    cheat
];
in
{
    home.packages = packageList;
}
;}
