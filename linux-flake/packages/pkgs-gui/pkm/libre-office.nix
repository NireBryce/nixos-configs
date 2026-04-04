# libreoffice - office productivity software https://www.libreoffice.org/
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        libreoffice-qt
    ];
}
