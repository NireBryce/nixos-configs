{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.vivid ];

    flake.modules.homeManager.vivid =
# vivid - LS_COLORS generator
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        vivid
    ];
}
;}
