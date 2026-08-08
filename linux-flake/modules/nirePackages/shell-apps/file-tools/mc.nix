{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in { 
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # # description = "midnight commander file browser";
            home.packages = with pkgs; [
                mc
            ];
        };
}
