{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.packages._.${moduleName}.homeManager = {
        # description = "`lsusb` https://www.linux-usb.org/";
        home.packages = with pkgs; [
            usbutils
        ];
    };
}
