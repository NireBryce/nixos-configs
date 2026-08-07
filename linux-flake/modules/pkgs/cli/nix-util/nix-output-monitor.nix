{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.nix-output-monitor ];

    flake.modules.homeManager.nix-output-monitor =
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        nix-output-monitor
    ];
}
;}
