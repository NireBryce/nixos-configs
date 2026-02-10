# desc = "network scanner http://www.nmap.org/";
{ den.bundles.hm.linux-sysadmin-tools =
{ pkgs, ... }:
let packageList = with pkgs; [
    nmap
];
in
{
    home.packages = packageList;
}
;}
