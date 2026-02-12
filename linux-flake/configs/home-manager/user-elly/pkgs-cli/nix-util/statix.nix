# desc = "nix antipattern linter";
# todo: move to nix dev
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    statix
];
in
{
    home.packages = packageList;
}
;}
