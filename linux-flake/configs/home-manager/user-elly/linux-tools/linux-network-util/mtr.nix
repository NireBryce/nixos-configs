# desc = "mtr - traceroute + ping https://www.bitwizard.nl/mtr/";
{ den.aspects.linux-tools.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    mtr
];
in
{
    home.packages = packageList;
}
;}
