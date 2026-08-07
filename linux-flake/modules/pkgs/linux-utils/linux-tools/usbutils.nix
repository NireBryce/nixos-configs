{ config, ... }:
{
    flake.modules.homeManager.pkgs-linux-utils.imports = [ config.flake.modules.homeManager.usbutils ];

    flake.modules.homeManager.usbutils =
# desc = "provides `lsusb` https://www.linux-usb.org/";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        usbutils
    ];
}
;}
