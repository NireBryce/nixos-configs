{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.system._.${moduleName}.nixos = {
        services.fwupd.enable = lib.mkDefault true;      # fwupd
    };
}
