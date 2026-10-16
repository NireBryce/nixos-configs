# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # `lsusb` https://www.linux-usb.org/
        home.packages = with pkgs; [
            usbutils
        ];
    };
}
