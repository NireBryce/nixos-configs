# desc = "lspci";
{ den.bundles.hm.linux-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    pciutils
];
in
{
    home.packages = packageList;
}
;}
