{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: { 
            # # description = "`df` alternative";
            home.packages = with pkgs; [
                duf
            ];
        };
}
