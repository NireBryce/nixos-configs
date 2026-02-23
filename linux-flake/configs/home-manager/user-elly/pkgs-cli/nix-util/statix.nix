# desc = "nix antipattern linter";
# todo: move to nix dev
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    statix
];
in
{
    home.packages = packageList;
}
;}
