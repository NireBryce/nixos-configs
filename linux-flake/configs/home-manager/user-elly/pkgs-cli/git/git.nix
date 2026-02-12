# git - git-scm
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    git
];
in
{
    home.packages = packageList;
}
;}
