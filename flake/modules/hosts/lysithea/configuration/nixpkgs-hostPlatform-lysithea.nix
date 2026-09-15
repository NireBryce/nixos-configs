{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.darwin.${moduleName} = {
            nixpkgs.hostPlatform = lib.mkDefault "aarch64-darwin";
        };
}
