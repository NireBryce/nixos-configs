# desc = "IP address calculator https://gitlab.com/ipcalc/ipcalc";
{ den.aspects.hm.provides.linux-tools = 
{ pkgs, ... }:
let packageList = with pkgs; [
    ipcalc
];
in
{
    home.packages = packageList;
}
;}
