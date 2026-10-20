# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # `lsusb` https://www.linux-usb.org/
        home.packages = with pkgs; [
            usbutils
        ];
    };
}
