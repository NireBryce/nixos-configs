# desc = "IP address calculator https://gitlab.com/ipcalc/ipcalc";
{ pkgs, ... }:
let packageList = with pkgs; [
    ipcalc
];
in
{
    home.packages = packageList;
}
