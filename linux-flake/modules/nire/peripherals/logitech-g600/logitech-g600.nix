{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.nixos = {
        services.ratbagd.enable = true;         # for piper logitech mouse ctl
    };
}
