{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.file ];

    flake.modules.homeManager.file =
# desc = "show filetype";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        file
    ];
}
;}
