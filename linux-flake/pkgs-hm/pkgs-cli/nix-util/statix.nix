# desc = "nix antipattern linter";
# todo: move to nix dev
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        statix
    ];
}
