{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.ruff ];

    flake.modules.homeManager.ruff =
# ruff - python linter
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        ruff
    ];
}
;}
