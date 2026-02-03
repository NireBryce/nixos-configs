# desc = "IP address calculator https://gitlab.com/ipcalc/ipcalc";
{ flake.modules.homeManager.commonLinux.networkUtil.ipcalc =
{ pkgs, ... }:
let packageList = with pkgs; [
    ipcalc
];
in
{
    home.packages = packageList;
}
;}
