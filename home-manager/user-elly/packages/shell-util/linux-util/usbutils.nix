{ ... }:
{
    description = "provides `lsusb` https://www.linux-usb.org/";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        usbutils
    ];
    in
    {
        home.packages = packageList;
    };
}
