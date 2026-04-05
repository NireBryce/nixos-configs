{
    description = "`lsusb` https://www.linux-usb.org/";

    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            usbutils
        ];
    };
}
