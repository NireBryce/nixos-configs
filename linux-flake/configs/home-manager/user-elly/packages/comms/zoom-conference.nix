# zoom videoconferencing software
{ den.bundles.hm.comms =
{ pkgs, ... }:
let packageList = with pkgs; [
    zoom-us
];
in
{
    home.packages = packageList;
}
;}
