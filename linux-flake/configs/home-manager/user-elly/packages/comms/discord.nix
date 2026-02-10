# discord gamer chat app that broke containment
{ den.bundles.hm.comms =
{ pkgs, ... }:
let packageList = with pkgs; [
    discord
];
in
{
    home.packages = packageList;
}
;}
