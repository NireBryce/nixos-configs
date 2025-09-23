{ pkgs, ... }:
let packageList = with pkgs; [
    topgrade
];
in
{
    home.packages = packageList;
    home.file."./.config/topgrade/config.toml".source = ./config/config.toml;
}
