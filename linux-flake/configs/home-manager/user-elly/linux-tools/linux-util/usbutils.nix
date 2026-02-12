# desc = "provides `lsusb` https://www.linux-usb.org/";
{ den.aspects.hm.provides.linux-tools = 
{ pkgs, ... }:
let packageList = with pkgs; [
    usbutils
];
in
{
    home.packages = packageList;
}
;}
