# cht.sh - cli cheatsheets
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    cheat
];
in
{
    home.packages = packageList;
}
;}
