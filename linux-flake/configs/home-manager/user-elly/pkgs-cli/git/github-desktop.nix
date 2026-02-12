# github-desktop - github gui
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    github-desktop
];
in
{
    home.packages = packageList;
}
;}
