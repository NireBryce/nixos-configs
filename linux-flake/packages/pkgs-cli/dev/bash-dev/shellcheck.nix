# shellcheck shellscript linter
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        shellcheck
    ];
}
