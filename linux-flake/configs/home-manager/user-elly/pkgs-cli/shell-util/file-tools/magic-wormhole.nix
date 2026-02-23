# wh - magic-wormhole point to point file transfer
{ den.aspects.pkgs-cli.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    magic-wormhole-rs
];
in
{
    home.packages = packageList;
}
;}
