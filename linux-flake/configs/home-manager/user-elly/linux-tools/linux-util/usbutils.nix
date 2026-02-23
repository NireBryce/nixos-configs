# desc = "provides `lsusb` https://www.linux-usb.org/";
{ den.aspects.linux-tools.homeManager = 
{ pkgs, ... }:
let packageList = with pkgs; [
    usbutils
];
in
{
    home.packages = packageList;
}
;}
