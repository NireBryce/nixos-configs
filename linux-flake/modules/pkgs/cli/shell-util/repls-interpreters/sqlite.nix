{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.sqlite ];

    flake.modules.homeManager.sqlite =
# desc = "sqlite";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        sqlite
    ];
}
;}
