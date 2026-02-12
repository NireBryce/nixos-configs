# cht.sh - cli cheatsheets
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    cheat
];
in
{
    home.packages = packageList;
}
;}
