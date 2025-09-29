# desc = "provides `lsusb` https://www.linux-usb.org/";
{ pkgs, ... }:
let packageList = with pkgs; [
    usbutils
];
in
{
    home.packages = packageList;
}
