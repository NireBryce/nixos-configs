# desc = " GNU Image Manipulation Program. https://www.gimp.org";
{ pkgs, ... }:
let
    packageList = with pkgs; [
        gimp
    ];
in 
{
    home.packages = packageList;
}
