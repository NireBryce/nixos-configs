{ 
    perSystem = {pkgs, lib, ...}:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = {
            # # description = "`lsusb` https://www.linux-usb.org/";
            home.packages = with pkgs; [
                usbutils
            ];
        };
    };
}
