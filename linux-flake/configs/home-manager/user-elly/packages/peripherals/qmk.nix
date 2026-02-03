# qmk - qmk keyboard firmware manager https://github.com/qmk/qmk_firmware";
{ flake.modules.homeManager.packages.peripherals.keyboard.qmk =
{ pkgs, ... }:
let
    packageList = with pkgs; [
        qmk
    ];
in 
{
    home.packages = packageList;
}
;}
