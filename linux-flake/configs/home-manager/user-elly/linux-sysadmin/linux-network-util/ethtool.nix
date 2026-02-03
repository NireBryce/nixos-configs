# desc = "ethtool https://www.kernel.org/pub/software/network/ethtool/";
{ flake.modules.homeManager.commonLinux.networkUtil.ethtool =
{ pkgs, ... }:
let packageList = with pkgs; [
    ethtool
];
in
{
    home.packages = packageList;
}
;}
