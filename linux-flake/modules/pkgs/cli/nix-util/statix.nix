{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.statix ];

    flake.modules.homeManager.statix =
# desc = "nix antipattern linter";
# todo: move to nix dev
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        statix
    ];
}
;}
