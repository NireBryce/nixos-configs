# piper - logitech/razer graphical mouse manager https://github.com/soxoj/piper";
{ flake.modules.homeManager.packages.peripherals.mouse.piper = 
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
