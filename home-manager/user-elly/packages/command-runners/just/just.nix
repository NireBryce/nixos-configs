# desc = "just - justfile runner";
{ pkgs, ... }:
let packageList = with pkgs; [
    just
];
in
{
    home.file = {
        "./.justfile"         .source = ./config/.justfile;
        "./.just/.justfile"   .source = ./config/.justfile;
        "./.just"             .source = ./config;
    };

    home.packages = packageList;
}
