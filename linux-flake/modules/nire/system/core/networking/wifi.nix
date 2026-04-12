{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.nixos = {
        networking.networkmanager.enable = true;        # Needs to be 'true' for KDE networking
    };
}
