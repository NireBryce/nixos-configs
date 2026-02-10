# desc = "ethtool https://www.kernel.org/pub/software/network/ethtool/";
{ den.bundles.hm.linux-sysadmin-tools =
{ pkgs, ... }:
let packageList = with pkgs; [
    ethtool
];
in
{
    home.packages = packageList;
}
;}
