{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.hyfetch ];

    flake.modules.homeManager.hyfetch =
# desc = "neofetch replacement https://github.com/hykilpikonna/HyFetch";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        hyfetch
    ];
}
;}
