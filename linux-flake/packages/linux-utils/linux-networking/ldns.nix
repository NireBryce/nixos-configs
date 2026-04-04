{ pkgs, ... }:
{
    home.packages = with pkgs; [
        # provides `drill`, a `dig` replacement https://www.nlnetlabs.nl/projects/ldns/about/
        ldns
    ];
}

