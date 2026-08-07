{ config, ... }:
{
    flake.modules.homeManager.pkgs-cli.imports = [ config.flake.modules.homeManager.yazi ];

    flake.modules.homeManager.yazi =
# yazi - file browser MAKE BETTER DESC
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        yazi
    ];
}
;}
