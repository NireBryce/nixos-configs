# desc = "per-character in-line diff";
{ flake.modules.homeManager.packages.shellUtil.riffdiff =
{ pkgs, ... }:
let packageList = with pkgs; [
    riffdiff
];
in
{
    home.packages = packageList;
}
;}
