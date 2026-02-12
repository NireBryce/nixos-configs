# discord gamer chat app that broke containment
{ den.aspects.hm.provides.pkgs-gui = 
{ pkgs, ... }:
let packageList = with pkgs; [
    discord
];
in
{
    home.packages = packageList;
}
;}
