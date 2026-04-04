{ pkgs, ... }:
{
    home.packages = with pkgs; [
        # ethtool https://www.kernel.org/pub/software/network/ethtool/
        ethtool
    ];
}
