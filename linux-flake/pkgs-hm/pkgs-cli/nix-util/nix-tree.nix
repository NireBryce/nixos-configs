# desc = "view dependency graph";
{ pkgs, ... }:
{
home.packages = with pkgs; [
    nix-tree
];
}
