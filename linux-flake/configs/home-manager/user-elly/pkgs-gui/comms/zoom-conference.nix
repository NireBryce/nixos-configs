# zoom videoconferencing software
{ den.aspects.pkgs-gui.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    zoom-us
];
in
{
    home.packages = packageList;
}
;}
