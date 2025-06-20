# desc = "zoom videoconferencing software https://zoom.us/";
{ pkgs, ... }:
let packageList = with pkgs; [
    zoom-us
];
in
{
    home.packages = packageList;
}
