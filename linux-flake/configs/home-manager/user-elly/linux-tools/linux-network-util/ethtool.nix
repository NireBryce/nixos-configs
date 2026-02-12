# desc = "ethtool https://www.kernel.org/pub/software/network/ethtool/";
{ den.aspects.hm.provides.linux-tools = 
{ pkgs, ... }:
let packageList = with pkgs; [
    ethtool
];
in
{
    home.packages = packageList;
}
;}
