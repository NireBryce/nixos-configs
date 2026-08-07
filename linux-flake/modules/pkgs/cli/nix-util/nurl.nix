{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.nurl ];

    flake.modules.homeManager.nurl =
# desc = "make nix fetcher calls from repository URLs";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        nurl
    ];
}
;}
