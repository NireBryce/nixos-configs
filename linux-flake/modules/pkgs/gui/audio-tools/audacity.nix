{ config, ... }:
{
    flake.modules.homeManager.pkgs-gui.imports = [ config.flake.modules.homeManager.audacity ];

    flake.modules.homeManager.audacity =
# desc = "Audacity audio editor";
{ pkgs, ... }:
{
home.packages = with pkgs; [
        audacity
    ];
# TODO: make this only load for workstation or audio workstation
}
;}
