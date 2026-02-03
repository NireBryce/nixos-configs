# git - git-scm
{ flake.modules.homeManager.packages.git.git =
{ pkgs, ... }:
let packageList = with pkgs; [
    git
];
in
{
    home.packages = packageList;
}
;}
