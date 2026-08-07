{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.duf ];

    flake.modules.homeManager.duf =
# desc = "`df` alternative";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        duf
    ];
}
;}
