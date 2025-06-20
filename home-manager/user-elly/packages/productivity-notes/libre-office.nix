# desc = "office productivity software https://www.libreoffice.org/";
{ pkgs, ... }:
let
    packageList = with pkgs; [
        libreoffice-qt
    ];
in 
{
    home.packages = packageList;
}
