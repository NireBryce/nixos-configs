# desc = "provides `drill`, a `dig` replacement https://www.nlnetlabs.nl/projects/ldns/about/";
{ flake.modules.homeManager.commonLinux.networkUtil.ldns =
{ pkgs, ... }:
let packageList = with pkgs; [
    ldns
];
in
{
    home.packages = packageList;
}
;}
