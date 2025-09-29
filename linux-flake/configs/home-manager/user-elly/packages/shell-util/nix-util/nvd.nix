# desc = "nix package version diff";
{ pkgs, ... }:
let packageList = with pkgs; [
    nvd
];
in
{
    home.packages = packageList;
}
