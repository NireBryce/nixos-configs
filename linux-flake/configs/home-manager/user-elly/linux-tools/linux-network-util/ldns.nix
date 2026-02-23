# desc = "provides `drill`, a `dig` replacement https://www.nlnetlabs.nl/projects/ldns/about/";
{ den.aspects.linux-tools.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    ldns
];
in
{
    home.packages = packageList;
}
;}
