# wh - magic-wormhole point to point file transfer
{ den.bundles.hm.shell-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    magic-wormhole-rs
];
in
{
    home.packages = packageList;
}
;}
