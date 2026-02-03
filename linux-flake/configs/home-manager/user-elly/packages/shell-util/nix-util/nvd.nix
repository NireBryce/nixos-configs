# desc = "nix package version diff";
{ flake.modules.homeManager.packages.nix.nvd =
{ pkgs, ... }:
let packageList = with pkgs; [
    nvd
];
in
{
    home.packages = packageList;
}
;}
