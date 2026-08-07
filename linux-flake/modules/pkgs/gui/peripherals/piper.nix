{ config, ... }:
{
    flake.modules.homeManager.pkgs-gui.imports = [ config.flake.modules.homeManager.piper ];

    flake.modules.homeManager.piper =
# piper - logitech/razer graphical mouse manager https://github.com/soxoj/piper";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        piper
    ];
}
;}
