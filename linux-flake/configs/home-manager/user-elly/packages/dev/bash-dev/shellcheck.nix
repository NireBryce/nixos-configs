# shellcheck shellscript linter
{ den.bundles.hm.dev-tools =
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        shellcheck
    ];
}
;}
