# desc = "mtr - traceroute + ping https://www.bitwizard.nl/mtr/";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        mtr
    ];
}
