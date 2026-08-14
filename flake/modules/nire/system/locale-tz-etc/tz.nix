{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
    flake.modules.nixos.${moduleName} = {
            time.timeZone = lib.mkDefault "America/New_York";
        };
}
