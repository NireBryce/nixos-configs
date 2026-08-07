{ config, ... }:
{
    flake.modules.homeManager.pkgs-linux-utils.imports = [ config.flake.modules.homeManager.pciutils ];

    flake.modules.homeManager.pciutils =
# desc = "lspci";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        pciutils
    ];
}
;}
