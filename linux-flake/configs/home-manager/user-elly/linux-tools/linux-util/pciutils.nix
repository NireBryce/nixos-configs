# desc = "lspci";
{ den.aspects.linux-tools.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    pciutils
];
in
{
    home.packages = packageList;
}
;}
