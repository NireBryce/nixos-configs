{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.aria2 ];

    flake.modules.homeManager.aria2 =
# aria2 -cli download manager
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        aria2
    ];
}
;}
