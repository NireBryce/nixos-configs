# desc = "view dependency graph";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    nix-tree
];
in
{
home.packages = packageList;
}
;}
