{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.manix ];

    flake.modules.homeManager.manix =
# desc = "nix man pages, kinda";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        manix
    ];
}
;}
