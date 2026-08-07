{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.lazygit ];

    flake.modules.homeManager.lazygit =
# lazygit - TUI git interface
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        lazygit
    ];
}
;}
