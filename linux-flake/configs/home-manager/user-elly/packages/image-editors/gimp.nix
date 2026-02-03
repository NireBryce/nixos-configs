# gimp - the GNU Image Manipulation Program. https://www.gimp.org
{ flake.modules.homeManager.packages.imageEditors.gimp =
{ pkgs, ... }:
let
    packageList = with pkgs; [
        gimp
    ];
in 
{
    home.packages = packageList;
}
;}
