# desc = "mtr - traceroute + ping https://www.bitwizard.nl/mtr/";
{ pkgs, ... }:
let packageList = with pkgs; [
    mtr
];
in
{
    home.packages = packageList;
}
