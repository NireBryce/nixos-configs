# desc = "mtr - traceroute + ping https://www.bitwizard.nl/mtr/";
{ flake.modules.homeManager.commonLinux.networkUtil.mtr =
{ pkgs, ... }:
let packageList = with pkgs; [
    mtr
];
in
{
    home.packages = packageList;
}
;}
