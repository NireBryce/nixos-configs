{ config, ... }:
{
    flake.modules.homeManager.pkgs-linux-utils.imports = [ config.flake.modules.homeManager.ethtool ];

    flake.modules.homeManager.ethtool =
# desc = "ethtool https://www.kernel.org/pub/software/network/ethtool/";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        ethtool
    ];
}
;}
