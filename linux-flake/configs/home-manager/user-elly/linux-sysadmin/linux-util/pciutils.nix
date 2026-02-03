# desc = "lspci";
{ flake.modules.homeManager.commonLinux.linuxUtil.pciutils =
{ pkgs, ... }:
let packageList = with pkgs; [
    pciutils
];
in
{
    home.packages = packageList;
}
;}
