# desc = "provides `drill`, a `dig` replacement https://www.nlnetlabs.nl/projects/ldns/about/";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        ldns
    ];
}

