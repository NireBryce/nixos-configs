# desc = "per-character in-line diff";
{ pkgs, ... }:
let packageList = with pkgs; [
    riffdiff
];
in
{
    home.packages = packageList;
}
