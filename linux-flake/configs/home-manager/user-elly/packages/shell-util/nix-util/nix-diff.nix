# desc = "diff nix code";
{ flake.modules.homeManager.packages.nix.nix-diff =
{ pkgs, ... }:
let packageList = with pkgs; [
    nix-diff
];
in
{
    home.packages = packageList;
}
;}
