# desc = "IP address calculator https://gitlab.com/ipcalc/ipcalc";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        ipcalc
    ];
}
