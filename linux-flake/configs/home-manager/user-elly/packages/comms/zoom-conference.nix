# zoom videoconferencing software
{ flake.modules.homeManager.packages.comms.zoom =
{ pkgs, ... }:
let packageList = with pkgs; [
    zoom-us
];
in
{
    home.packages = packageList;
}
;}
