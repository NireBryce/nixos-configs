# desc = "provides `drill`, a `dig` replacement https://www.nlnetlabs.nl/projects/ldns/about/";
{ pkgs, ... }:
let packageList = with pkgs; [
    ldns
];
in
{
    home.packages = packageList;
}
