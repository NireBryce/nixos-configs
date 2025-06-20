# desc = "lspci";
{ pkgs, ... }:
let packageList = with pkgs; [
    pciutils
];
in
{
    home.packages = packageList;
}
