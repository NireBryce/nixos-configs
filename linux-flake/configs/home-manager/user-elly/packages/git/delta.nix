# delta - a better git diff viewer
{ flake.modules.homeManager.packages.git.delta = 
{ pkgs, ... }:
let packageList = with pkgs; [
    delta
];
in
{
    home.packages = packageList;
}
;}
