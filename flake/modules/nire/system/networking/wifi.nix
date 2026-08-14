{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            networking.networkmanager.enable = true; # Needs to be 'true' for KDE networking
        };
}
