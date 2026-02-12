# desc = "view dependency graph";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    nix-tree
];
in
{
home.packages = packageList;
}
;}
