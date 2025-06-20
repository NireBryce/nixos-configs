# desc = "view dependency graph";
{ pkgs, ... }:
let packageList = with pkgs; [
    nix-tree
];
in
{
home.packages = packageList;
}
