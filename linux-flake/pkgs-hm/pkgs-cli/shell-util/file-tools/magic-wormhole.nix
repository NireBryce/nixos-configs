# wh - magic-wormhole point to point file transfer
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        magic-wormhole-rs
    ];
}
