{ config, ... }:
{
    flake.modules.homeManager.pkgs-linux-utils.imports = [ config.flake.modules.homeManager.mtr ];

    flake.modules.homeManager.mtr =
# desc = "mtr - traceroute + ping https://www.bitwizard.nl/mtr/";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        mtr
    ];
}
;}
