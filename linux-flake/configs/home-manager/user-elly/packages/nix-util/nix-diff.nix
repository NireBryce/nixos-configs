# desc = "diff nix code";
{ den.bundles.hm.nix-util = 
{ pkgs, ... }:
let packageList = with pkgs; [
    nix-diff
];
in
{
    home.packages = packageList;
}
;}
