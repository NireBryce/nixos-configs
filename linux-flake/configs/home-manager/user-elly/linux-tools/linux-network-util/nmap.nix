# desc = "network scanner http://www.nmap.org/";
{ den.aspects.hm.provides.linux-tools = 
{ pkgs, ... }:
let packageList = with pkgs; [
    nmap
];
in
{
    home.packages = packageList;
}
;}
