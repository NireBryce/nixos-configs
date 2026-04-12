{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.nixos = {
        networking.hostName = "nire-durandal"; # can maybe get rid of this with den.provides.hostname doing the work
    };
}
