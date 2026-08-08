{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: { 
            # # description = "run multiple commands in parallel";
            home.packages = with pkgs; [
                mprocs
            ];
        };
}
