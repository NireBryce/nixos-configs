# desc = "IP address calculator https://gitlab.com/ipcalc/ipcalc";
{ den.bundles.hm.linux-sysadmin-tools =
{ pkgs, ... }:
let packageList = with pkgs; [
    ipcalc
];
in
{
    home.packages = packageList;
}
;}
