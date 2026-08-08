{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            hardware.bluetooth.powerOnBoot = true;
            hardware.bluetooth.enable = true;
            hardware.bluetooth.settings = {
                General = {
                FastConnectable = true;
                DiscoverableTimeout = 60; # seconds
                PairableTimeout = 60; # seconds
                };
            };
        };
}
