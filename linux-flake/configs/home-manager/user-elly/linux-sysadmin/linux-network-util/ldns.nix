# desc = "provides `drill`, a `dig` replacement https://www.nlnetlabs.nl/projects/ldns/about/";
{ den.bundles.hm.linux-sysadmin-tools =
{ pkgs, ... }:
let packageList = with pkgs; [
    ldns
];
in
{
    home.packages = packageList;
}
;}
