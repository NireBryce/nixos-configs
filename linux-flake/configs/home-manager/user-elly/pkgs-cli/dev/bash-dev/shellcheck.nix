# shellcheck shellscript linter
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        shellcheck
    ];
}
;}
