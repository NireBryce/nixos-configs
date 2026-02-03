# discord gamer chat app that broke containment
{ flake.modules.homeManager.packages.comms.discord =
{ pkgs, ... }:
let packageList = with pkgs; [
    discord
];
in
{
    home.packages = packageList;
}
;}
