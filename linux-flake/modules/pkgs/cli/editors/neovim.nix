{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.neovim ];

    flake.modules.homeManager.neovim =
# neovim - it's like vim but heavier
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        neovim
    ];
}
;}
