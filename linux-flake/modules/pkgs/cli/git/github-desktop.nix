{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.github-desktop ];

    flake.modules.homeManager.github-desktop =
# github-desktop - github gui 
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        github-desktop
    ];
}
;}
