{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.nixos = {
        services.fwupd.enable = lib.mkDefault true;      # fwupd
    };
}
