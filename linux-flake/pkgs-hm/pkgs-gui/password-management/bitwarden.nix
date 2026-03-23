# bitwarden - password manager https://bitwarden.com/";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        bitwarden-desktop
    ];
}
