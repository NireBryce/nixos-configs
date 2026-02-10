# desc = "per-character in-line diff";
{ den.bundles.hm.shell-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    riffdiff
];
in
{
    home.packages = packageList;
}
;}
