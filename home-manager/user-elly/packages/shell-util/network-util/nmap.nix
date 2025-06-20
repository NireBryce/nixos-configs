# desc = "network scanner http://www.nmap.org/";
{ pkgs, ... }:
let packageList = with pkgs; [
    nmap
];
in
{
    home.packages = packageList;
}
