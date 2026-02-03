# github-desktop - github gui
{ flake.modules.homeManager.packages.git.github-desktop =
{ pkgs, ... }:
let packageList = with pkgs; [
    github-desktop
];
in
{
    home.packages = packageList;
}
;}
