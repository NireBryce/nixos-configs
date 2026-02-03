# desc = "nix antipattern linter";
# todo: move to nix dev
{ flake.modules.homeManager.development.nix-dev.linters.statix =
{ pkgs, ... }:
let packageList = with pkgs; [
    statix
];
in
{
    home.packages = packageList;
}
;}
