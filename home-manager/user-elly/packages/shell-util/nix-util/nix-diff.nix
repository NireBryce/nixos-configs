# desc = "diff nix code";
{ pkgs, ... }:
let packageList = with pkgs; [
    nix-diff
];
in
{
    home.packages = packageList;
}
