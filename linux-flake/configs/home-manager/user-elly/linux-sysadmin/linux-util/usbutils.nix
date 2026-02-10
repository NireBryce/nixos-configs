# desc = "provides `lsusb` https://www.linux-usb.org/";
{ den.bundles.hm.linux-util =
{ pkgs, ... }:
let packageList = with pkgs; [
    usbutils
];
in
{
    home.packages = packageList;
}
;}
