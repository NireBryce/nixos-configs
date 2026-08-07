{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.git ];

    flake.modules.homeManager.git =
# git - git-scm
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        git
    ];
}
;}
