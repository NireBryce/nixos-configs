# vlc - VLC media player
{ den.aspects.hm.provides.pkgs-gui = 
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
