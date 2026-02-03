# libreoffice - office productivity software https://www.libreoffice.org/
{ flake.modules.homeManager.packages.productivity.libreOffice =
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
