{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nireHost.durandal._.${moduleName}.nixos = {
        system.stateVersion = "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
    };
}
