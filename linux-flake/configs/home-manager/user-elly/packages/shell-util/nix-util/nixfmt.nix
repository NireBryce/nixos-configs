# desc = "nix formatter";
# TODO: dedupe, exists in develop
{ flake.modules.homeManager.packages.nix.nixfmt =
{ pkgs, ... }:
let packageList = with pkgs; [
    nixfmt
];
in
{
    home.packages = packageList;
}
;}
