# piper - logitech/razer graphical mouse manager https://github.com/soxoj/piper";
{ den.aspects.hm.provides.pkgs-gui = 
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
