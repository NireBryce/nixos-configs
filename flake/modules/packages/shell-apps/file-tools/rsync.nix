{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # rsync - back in my day we transfered our files uphill both ways
            home.packages = with pkgs; [
                rsync
            ];
        };
}
