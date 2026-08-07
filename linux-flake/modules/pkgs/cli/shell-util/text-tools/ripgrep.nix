{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.ripgrep ];

    flake.modules.homeManager.ripgrep =
# desc = "`rg` much faster grep alternative";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        ripgrep
    ];
}
;}
