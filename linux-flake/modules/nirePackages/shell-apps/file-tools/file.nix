{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # # description = "an application to show file info";
            home.packages = with pkgs; [
                file
            ];
        };
}
