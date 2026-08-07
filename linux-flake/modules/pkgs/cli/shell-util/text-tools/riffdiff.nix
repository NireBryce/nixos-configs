{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.riffdiff ];

    flake.modules.homeManager.riffdiff =
# desc = "per-character in-line diff";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        riffdiff
    ];
}
;}
