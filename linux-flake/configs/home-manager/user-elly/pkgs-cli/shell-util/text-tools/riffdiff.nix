# desc = "per-character in-line diff";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    riffdiff
];
in
{
    home.packages = packageList;
}
;}
