{ config, ... }:
{
    flake.modules.homeManager.pkgs-gui.imports = [ config.flake.modules.homeManager.vlc ];

    flake.modules.homeManager.vlc =
# vlc - VLC media player
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        vlc
    ];
}
;}
