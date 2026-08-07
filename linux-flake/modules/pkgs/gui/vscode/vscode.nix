{ config, ... }:
{
    flake.modules.homeManager.pkgs-gui.imports = [ config.flake.modules.homeManager.vscode ];

    flake.modules.homeManager.vscode =
{ pkgs, ...}:
{
    programs.vscode = {
        enable = true;
        package = pkgs.vscode-fhs;
    };
}

    # TODO: this is needed for vscode to work do not remove this package
;}
