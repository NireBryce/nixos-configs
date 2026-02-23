# desc = "network scanner http://www.nmap.org/";
{ den.aspects.linux-tools.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    nmap
];
in
{
    home.packages = packageList;
}
;}
