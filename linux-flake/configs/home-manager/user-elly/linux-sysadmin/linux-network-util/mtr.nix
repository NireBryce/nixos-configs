# desc = "mtr - traceroute + ping https://www.bitwizard.nl/mtr/";
{ den.bundles.hm.linux-sysadmin-tools =
{ pkgs, ... }:
let packageList = with pkgs; [
    mtr
];
in
{
    home.packages = packageList;
}
;}
