{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.nvd ];

    flake.modules.homeManager.nvd =
# desc = "nix package version diff";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        nvd
    ];
}
;}
