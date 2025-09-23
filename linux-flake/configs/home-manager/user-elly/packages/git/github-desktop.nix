# desc = "github desktop";
{ pkgs, ... }:
let packageList = with pkgs; [
    github-desktop
];
in
{
    home.packages = packageList;
}
