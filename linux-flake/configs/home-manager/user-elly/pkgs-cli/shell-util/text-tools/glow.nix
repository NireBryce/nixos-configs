# desc = "terminal markdown viewer https://github.com/charmbracelet/glow";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    glow
];
in
{
    home.packages = packageList;
}
;}
