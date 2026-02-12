# bitwarden - password manager https://bitwarden.com/";
{ den.aspects.hm.provides.pkgs-gui = 
{ pkgs, ... }:
let packageList = with pkgs; [
    bitwarden-desktop
];
in
{
    home.packages = packageList;
}
;}
