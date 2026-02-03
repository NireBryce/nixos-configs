# desc = "view dependency graph";
{ flake.modules.homeManager.packages.nix.nix-tree =
{ pkgs, ... }:
let packageList = with pkgs; [
    nix-tree
];
in
{
home.packages = packageList;
}
;}
