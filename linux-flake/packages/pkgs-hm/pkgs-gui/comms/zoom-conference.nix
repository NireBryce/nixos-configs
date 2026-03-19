# zoom videoconferencing software
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        zoom-us
    ];
}
