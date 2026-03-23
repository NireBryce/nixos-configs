# desc = "ethtool https://www.kernel.org/pub/software/network/ethtool/";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        ethtool
    ];
}
