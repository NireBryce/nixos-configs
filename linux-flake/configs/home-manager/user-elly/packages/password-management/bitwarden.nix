# desc = "Bitwarden password manager https://bitwarden.com/";
{ pkgs, ... }:
let packageList = with pkgs; [
    bitwarden-desktop
];
in
{
    home.packages = packageList;
}
