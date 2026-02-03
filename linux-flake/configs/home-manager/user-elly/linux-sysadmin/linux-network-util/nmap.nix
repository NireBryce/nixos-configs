# desc = "network scanner http://www.nmap.org/";
{ flake.modules.homeManager.commonLinux.networkUtil.nmap =
{ pkgs, ... }:
let packageList = with pkgs; [
    nmap
];
in
{
    home.packages = packageList;
}
;}
