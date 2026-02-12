# desc = "diff nix code";
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    nix-diff
];
in
{
    home.packages = packageList;
}
;}
