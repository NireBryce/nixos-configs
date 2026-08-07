{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.fselect ];

    flake.modules.homeManager.fselect =
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        fselect
    ];
}
;}
