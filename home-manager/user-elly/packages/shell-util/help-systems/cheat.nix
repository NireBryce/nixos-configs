# desc = "cli cheatsheets";
{ pkgs, ... }:
let packageList = with pkgs; [
    cheat
];
in
{
    home.packages = packageList;
}
