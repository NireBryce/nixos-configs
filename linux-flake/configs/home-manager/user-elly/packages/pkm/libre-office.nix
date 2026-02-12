# libreoffice - office productivity software https://www.libreoffice.org/
{ den.bundles.hm.productivity =
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
