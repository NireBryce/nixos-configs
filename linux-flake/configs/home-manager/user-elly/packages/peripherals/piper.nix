# piper - logitech/razer graphical mouse manager https://github.com/soxoj/piper";
{ den.bundles.hm.peripherals =
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
