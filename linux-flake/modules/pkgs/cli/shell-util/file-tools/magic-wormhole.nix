{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.magic-wormhole ];

    flake.modules.homeManager.magic-wormhole =
# wh - magic-wormhole point to point file transfer
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        magic-wormhole-rs
    ];
}
;}
