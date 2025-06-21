# desc = "nix antipattern linter";
{ pkgs, ... }:
let packageList = with pkgs; [
    statix
];
in
{
    home.packages = packageList;
}
