# gimp - the GNU Image Manipulation Program. https://www.gimp.org
{ den.aspects.hm.provides.pkgs-gui = 
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
