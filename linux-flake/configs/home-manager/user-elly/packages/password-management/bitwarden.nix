# bitwarden - password manager https://bitwarden.com/";
{ den.bundles.hm.password-management =
{ pkgs, ... }:
let packageList = with pkgs; [
    bitwarden-desktop
];
in
{
    home.packages = packageList;
}
;}
