# desc = "lspci";
{ den.aspects.hm.provides.linux-tools = 
{ pkgs, ... }:
let packageList = with pkgs; [
    pciutils
];
in
{
    home.packages = packageList;
}
;}
