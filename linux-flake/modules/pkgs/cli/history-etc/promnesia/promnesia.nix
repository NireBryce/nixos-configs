{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.promnesia ];

    flake.modules.homeManager.promnesia =
# desc = "promnesia breadcrumb-bookmarks-and-more";
{ ... }:
{
    home.file.".config/promnesia".source = ./config/config.py;
}
;}
