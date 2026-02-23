# gimp - the GNU Image Manipulation Program. https://www.gimp.org
{ den.aspects.pkgs-gui.homeManager = 
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
