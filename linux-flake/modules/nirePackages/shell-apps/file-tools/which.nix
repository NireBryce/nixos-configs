{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in { 
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # # description = "which - find the location of a given command's binary";
            home.packages = with pkgs; [
                which
            ];
        };
}
