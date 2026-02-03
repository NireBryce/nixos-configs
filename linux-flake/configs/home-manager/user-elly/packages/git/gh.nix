# gh - github-cli
{ flake.modules.homeManager.packages.git.github-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    gh
];
in
{
    home.packages = packageList;
}
;}
