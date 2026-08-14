{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            hardware.enableAllFirmware = true;
            hardware.enableRedistributableFirmware = true;
            nixpkgs.config.allowUnfree = true; # enableAllFirmware depends on this
        };
}
