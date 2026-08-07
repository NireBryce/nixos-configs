{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.which ];

    flake.modules.homeManager.which =
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        which
    ];
}
;}
