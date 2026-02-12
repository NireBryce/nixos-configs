# wh - magic-wormhole point to point file transfer
{ den.aspects.hm.provides.pkgs-cli = 
{ pkgs, ... }:
let packageList = with pkgs; [
    magic-wormhole-rs
];
in
{
    home.packages = packageList;
}
;}
