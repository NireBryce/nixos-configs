{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "`lsusb` https://www.linux-usb.org/";
      home.packages = with pkgs; [
        usbutils
      ];
    };};
}
