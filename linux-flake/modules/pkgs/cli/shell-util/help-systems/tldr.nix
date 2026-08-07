{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.tldr ];

    flake.modules.homeManager.tldr =
# tldr - community provided man pages
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        tldr
    ];
}
;}
