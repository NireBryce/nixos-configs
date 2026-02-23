# piper - logitech/razer graphical mouse manager https://github.com/soxoj/piper";
{ den.aspects.pkgs-gui.homeManager = 
{ pkgs, ... }:
let
    packageList = with pkgs; [
        piper
    ];
in 
{
    home.packages = packageList;
}
;}
