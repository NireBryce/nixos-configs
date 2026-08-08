{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # # description = "vivid - LS_COLORS generator";
            home.packages = with pkgs; [
                vivid
            ];
        };
}
