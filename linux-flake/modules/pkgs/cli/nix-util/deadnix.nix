{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.deadnix ];

    flake.modules.homeManager.deadnix =
# desc = "scan for 'dead' (uncalled) nix code";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        deadnix
    ];
}
;}
