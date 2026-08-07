{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.cheat ];

    flake.modules.homeManager.cheat =
# cht.sh - cli cheatsheets
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        cheat
    ];
}
;}
