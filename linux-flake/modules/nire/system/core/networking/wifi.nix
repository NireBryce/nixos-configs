{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.system._.${moduleName}.nixos = {
        networking.networkmanager.enable = true;        # Needs to be 'true' for KDE networking
    };
}
