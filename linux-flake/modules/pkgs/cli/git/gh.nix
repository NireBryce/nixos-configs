{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.gh ];

    flake.modules.homeManager.gh =
# gh - github-cli
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        gh
    ];
}
;}
