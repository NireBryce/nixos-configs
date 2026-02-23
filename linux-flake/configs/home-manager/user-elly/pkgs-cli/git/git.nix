# git - git-scm
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    git
];
in
{
    home.packages = packageList;
}
;}
