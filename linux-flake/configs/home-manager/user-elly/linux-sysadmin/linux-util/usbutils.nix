# desc = "provides `lsusb` https://www.linux-usb.org/";
{ flake.modules.homeManager.commonLinux.linuxUtil.usbutils =
{ pkgs, ... }:
let packageList = with pkgs; [
    usbutils
];
in
{
    home.packages = packageList;
}
;}
