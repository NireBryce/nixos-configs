# desc = "diff nix code";
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    nix-diff
];
in
{
    home.packages = packageList;
}
;}
