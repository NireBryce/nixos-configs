# shellcheck shellscript linter
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        shellcheck
    ];
}
;}
