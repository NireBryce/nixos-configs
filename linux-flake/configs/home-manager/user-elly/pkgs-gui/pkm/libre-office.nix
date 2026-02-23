# libreoffice - office productivity software https://www.libreoffice.org/
{ den.aspects.pkgs-gui.homeManager = 
{ pkgs, ... }:
let
    packageList = with pkgs; [
        libreoffice-qt
    ];
in 
{
    home.packages = packageList;
}
;}
