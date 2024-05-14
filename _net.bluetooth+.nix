# Bluetooth support
# https://github.com/jpas/etc-nixos/blob/365e5301e559af29eafec7f7c391f1c84b6c6477/profiles/hardware/bluetooth.nix
{ lib, config, ... }: 

{
  options = {
    _bluetooth.enable = lib.mkEnableOption "Enables bluetooth settings";
  };
  config = lib.mkIf config._bluetooth.enable {
    hardware.bluetooth.powerOnBoot = lib.mkDefault true;
    # services.blueman.enable = true;
    hardware.bluetooth.enable = lib.mkDefault true;
    hardware.bluetooth.settings = {
      General = {
        FastConnectable = lib.mkDefault true;
        DiscoverableTimeout = lib.mkDefault 60; # seconds
        PairableTimeout = lib.mkDefault 60; # seconds
      };
    };
  };
}
