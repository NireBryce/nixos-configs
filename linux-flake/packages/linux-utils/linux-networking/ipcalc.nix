{ pkgs, ... }:
{
    home.packages = with pkgs; [
        # IP address calculator https://gitlab.com/ipcalc/ipcalc
        ipcalc
    ];
}
