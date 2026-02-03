# bitwarden - password manager https://bitwarden.com/";
{ flake.modules.homeManager.packages.passwordManagers.bitwarden =
{ pkgs, ... }:
let packageList = with pkgs; [
    bitwarden-desktop
];
in
{
    home.packages = packageList;
}
;}
