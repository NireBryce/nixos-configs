{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # # description = "wh - magic-wormhole point to point file transfer";
            home.packages = with pkgs; [
                magic-wormhole-rs
            ];
        };
}
