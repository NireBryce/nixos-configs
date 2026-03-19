# gimp - the GNU Image Manipulation Program. https://www.gimp.org
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        gimp
    ];
}
