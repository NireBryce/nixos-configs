{ config, ... }:
{
    flake.modules.homeManager.pkgs-gui.imports = [ config.flake.modules.homeManager.just ];

    flake.modules.homeManager.just =
# desc = "just - justfile runner";
{ pkgs, ... }:
{
    home.file = {
        "./.justfile"         .source = ./config/.justfile;
        "./.just/.justfile"   .source = ./config/.justfile;
        "./.just"             .source = ./config;
    };

    home.packages = with pkgs; [
        just
    ];
}
;}
