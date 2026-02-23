# bitwarden - password manager https://bitwarden.com/";
{ den.aspects.pkgs-gui.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    bitwarden-desktop
];
in
{
    home.packages = packageList;
}
;}
