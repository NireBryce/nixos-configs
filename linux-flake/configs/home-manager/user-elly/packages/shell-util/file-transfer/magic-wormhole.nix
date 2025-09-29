# desc = "magic-wormhole point to point file transfer";
{ pkgs, ... }:
let packageList = with pkgs; [
    magic-wormhole-rs
];
in
{
    home.packages = packageList;
}
