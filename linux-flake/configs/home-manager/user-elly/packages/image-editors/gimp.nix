# gimp - the GNU Image Manipulation Program. https://www.gimp.org
{ den.bundles.hm.image-edit =
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
