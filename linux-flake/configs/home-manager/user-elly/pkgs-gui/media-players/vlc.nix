# vlc - VLC media player
{ den.aspects.pkgs-gui.homeManager = 
{ pkgs, ... }:
let
    packageList = with pkgs; [
        vlc
    ];
in 
{
    home.packages = packageList;
}
;}
