# desc = "ethtool https://www.kernel.org/pub/software/network/ethtool/";
{ den.aspects.linux-tools.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    ethtool
];
in
{
    home.packages = packageList;
}
;}
