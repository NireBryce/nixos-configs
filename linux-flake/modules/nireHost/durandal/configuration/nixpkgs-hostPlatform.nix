{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nireHost.durandal._.${moduleName}.nixos = {
        nixpkgs.hostPlatform = "x86_64-linux";
    };
}
