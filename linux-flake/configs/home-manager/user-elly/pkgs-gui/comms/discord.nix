# discord gamer chat app that broke containment
{ den.aspects.pkgs-gui.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    discord
];
in
{
    home.packages = packageList;
}
;}
