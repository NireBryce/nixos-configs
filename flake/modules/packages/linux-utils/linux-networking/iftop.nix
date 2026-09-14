{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in { 
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # network monitor https://pdw.ex-parrot.com/iftop/
            home.packages = with pkgs; [
                iftop
            ];
        };
}
