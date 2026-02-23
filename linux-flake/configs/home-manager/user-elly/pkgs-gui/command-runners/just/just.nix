# desc = "just - justfile runner";
{ den.aspects.pkgs-gui.homeManager = 
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
