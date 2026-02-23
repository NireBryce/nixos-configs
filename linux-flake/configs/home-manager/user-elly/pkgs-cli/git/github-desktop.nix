# github-desktop - github gui
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    github-desktop
];
in
{
    home.packages = packageList;
}
;}
