# desc = "just - justfile runner";
{ den.bundles.hm.command-runners =
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
