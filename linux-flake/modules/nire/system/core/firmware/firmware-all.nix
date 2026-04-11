{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.system._.${moduleName}.nixos = {
        hardware.enableAllFirmware = true;
        hardware.enableRedistributableFirmware = true;
        nixpkgs.config.allowUnfree = true; # enableAllFirmware depends on this
    };
}
