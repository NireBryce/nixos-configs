{ pkgs, ... }:
{
# provides `lsusb` https://www.linux-usb.org/
    home.packages = with pkgs; [
        usbutils
    ];
}
