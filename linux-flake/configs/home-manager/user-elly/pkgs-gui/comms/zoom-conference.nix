# zoom videoconferencing software
{ den.aspects.hm.provides.pkgs-gui = 
{ pkgs, ... }:
let packageList = with pkgs; [
    zoom-us
];
in
{
    home.packages = packageList;
}
;}
