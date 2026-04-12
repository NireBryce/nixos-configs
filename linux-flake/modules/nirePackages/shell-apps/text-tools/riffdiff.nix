{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = { pkgs, ... }: {
        # description = "per-character in-line diff";
        home.packages = with pkgs; [
            riffdiff
        ];
    };
}
