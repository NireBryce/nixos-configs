# desc = "nix antipattern linter";
# todo: move to nix dev
{ den.bundles.hm.nix-util = 
{ pkgs, ... }:
let packageList = with pkgs; [
    statix
];
in
{
    home.packages = packageList;
}
;}
