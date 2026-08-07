{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.du-dust ];

    flake.modules.homeManager.du-dust =
# desc = "`du` alternative";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        dust
    ];
}
;}
