# desc = "provides `lsusb` https://www.linux-usb.org/";
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        usbutils
    ];
}
