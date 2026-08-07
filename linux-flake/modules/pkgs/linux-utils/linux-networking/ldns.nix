{ config, ... }:
{
    flake.modules.homeManager.pkgs-linux-utils.imports = [ config.flake.modules.homeManager.ldns ];

    flake.modules.homeManager.ldns =
# desc = "provides `drill`, a `dig` replacement https://www.nlnetlabs.nl/projects/ldns/about/";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        ldns
    ];
}
;}
