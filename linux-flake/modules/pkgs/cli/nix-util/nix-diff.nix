{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.nix-diff ];

    flake.modules.homeManager.nix-diff =
# desc = "diff nix code";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        nix-diff
    ];
}
;}
