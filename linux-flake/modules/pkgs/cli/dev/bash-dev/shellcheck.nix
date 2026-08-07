{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.shellcheck ];

    flake.modules.homeManager.shellcheck =
# shellcheck shellscript linter
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        shellcheck
    ];
}
;}
