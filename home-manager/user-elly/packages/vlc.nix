# desc = "VLC media player";
{ pkgs, ... }:
let
    packageList = with pkgs; [
        vlc
    ];
in 
{
    home.packages = packageList;
}
