{ pkgs, ... }:
{
# mtr - traceroute + ping https://www.bitwizard.nl/mtr/
    home.packages = with pkgs; [
        mtr
    ];
}
