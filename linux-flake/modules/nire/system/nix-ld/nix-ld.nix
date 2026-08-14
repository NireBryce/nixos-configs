{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = {
        # nix-ld, needed for VSCode remote connection, etc
            programs.nix-ld.enable = lib.mkDefault true;
        };
}
