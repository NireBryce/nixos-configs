{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # `lsusb` https://www.linux-usb.org/
            home.packages = with pkgs; [
                usbutils
            ];
        };
}
