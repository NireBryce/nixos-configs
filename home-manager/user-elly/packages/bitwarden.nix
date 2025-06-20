# desc = "Bitwarden password manager https://bitwarden.com/";
{ pkgs, ... }:
let packageList = with pkgs; [
    bitwarden
];
in
{
    home.packages = packageList;
}
