{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # # description = "view nix dependency graph";
            home.packages = with pkgs; [
                nix-tree
            ];
        };
}
