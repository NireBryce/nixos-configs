{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = { pkgs, ... }: {
        # description = "`lsusb` https://www.linux-usb.org/";
        home.packages = with pkgs; [
            usbutils
        ];
    };
}
