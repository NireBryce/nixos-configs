# discord gamer chat app that broke containment
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        discord
    ];
}
