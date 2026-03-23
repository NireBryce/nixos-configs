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
