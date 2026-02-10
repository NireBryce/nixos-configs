# desc = "view dependency graph";
{ den.bundles.hm.nix-util = 
{ pkgs, ... }:
let packageList = with pkgs; [
    nix-tree
];
in
{
home.packages = packageList;
}
;}
