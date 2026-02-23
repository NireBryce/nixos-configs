# desc = "IP address calculator https://gitlab.com/ipcalc/ipcalc";
{ den.aspects.linux-tools.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    ipcalc
];
in
{
    home.packages = packageList;
}
;}
