# desc = " qmk keyboard manager https://github.com/qmk/qmk_firmware";
{ pkgs, ... }:
let
    packageList = with pkgs; [
        qmk
    ];
in 
{
    home.packages = packageList;
}
