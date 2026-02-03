# vlc - VLC media player
{ flake.modules.homeManager.packages.mediaPlayers.vlc =
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
