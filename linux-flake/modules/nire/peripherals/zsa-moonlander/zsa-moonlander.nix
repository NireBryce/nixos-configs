{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.packages._.${moduleName}.nixos = {
        hardware.keyboard.zsa.enable        = true;         # zsa keyboard package
    };
}
