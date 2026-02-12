# desc = "mtr - traceroute + ping https://www.bitwizard.nl/mtr/";
{ den.aspects.hm.provides.linux-tools = 
{ pkgs, ... }:
let packageList = with pkgs; [
    mtr
];
in
{
    home.packages = packageList;
}
;}
