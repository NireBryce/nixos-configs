# Bluetooth support
# https://github.com/jpas/etc-nixos/blob/365e5301e559af29eafec7f7c391f1c84b6c6477/profiles/hardware/bluetooth.nix
{ lib, config, ... }: 

{
  options = {
    _bluetooth.enable = lib.mkEnableOption "Enables bluetooth settings";
  };
  config = lib.mkIf config._bluetooth.enable {
    hardware.bluetooth.powerOnBoot = true;
    # services.blueman.enable = true; #TODO may need to disable
    hardware.bluetooth.enable =  true;
    hardware.bluetooth.settings = {
      General = {
        FastConnectable = true;
        DiscoverableTimeout =  60; # seconds
        PairableTimeout = 60; # seconds
      };
    };
  };
}
