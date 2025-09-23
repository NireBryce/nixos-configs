# desc = "ethtool https://www.kernel.org/pub/software/network/ethtool/";
{ pkgs, ... }:
let packageList = with pkgs; [
    ethtool
];
in
{
    home.packages = packageList;
}
