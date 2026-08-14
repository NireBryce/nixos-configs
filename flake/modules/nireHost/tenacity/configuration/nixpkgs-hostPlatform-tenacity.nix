{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
            nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
        };
}
