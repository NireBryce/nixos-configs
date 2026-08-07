{ config, ... }:
{
    flake.modules.homeManager.pkgs-gui.imports = [ config.flake.modules.homeManager.gimp ];

    flake.modules.homeManager.gimp =
# gimp - the GNU Image Manipulation Program. https://www.gimp.org
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        gimp
    ];
}
;}
