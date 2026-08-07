{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.glow ];

    flake.modules.homeManager.glow =
# desc = "terminal markdown viewer https://github.com/charmbracelet/glow";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        glow
    ];
}
;}
