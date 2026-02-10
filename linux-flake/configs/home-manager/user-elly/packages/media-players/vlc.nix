# vlc - VLC media player
{ den.bundles.hm.media-players =
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
