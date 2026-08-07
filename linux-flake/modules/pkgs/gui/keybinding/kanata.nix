{ config, ... }:
{
    flake.modules.homeManager.pkgs-gui.imports = [ config.flake.modules.homeManager.kanata ];

    flake.modules.homeManager.kanata =
# kanata - input-level keybinding, platform independent
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        kanata
    ];
}
;}
