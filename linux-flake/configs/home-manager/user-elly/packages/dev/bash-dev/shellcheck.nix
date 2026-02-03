# shellcheck shellscript linter
{ flake.modules.homeManager.development.shellscript.shellcheck =
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        shellcheck
    ];
}
;}
