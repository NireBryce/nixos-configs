{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            hardware.bluetooth = {
                powerOnBoot = true;
                enable = true;
                settings = {
                    General = {
                    FastConnectable = true;
                    DiscoverableTimeout = 60; # seconds
                    PairableTimeout = 60; # seconds
                    };
                };
            };
        };
}
