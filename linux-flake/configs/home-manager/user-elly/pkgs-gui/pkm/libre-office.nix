# libreoffice - office productivity software https://www.libreoffice.org/
{ den.aspects.hm.provides.pkgs-gui = 
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
