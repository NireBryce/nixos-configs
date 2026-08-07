{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.btop ];

    flake.modules.homeManager.btop =
# desc = "`htop` alternative";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        btop
    ];
}
;}
