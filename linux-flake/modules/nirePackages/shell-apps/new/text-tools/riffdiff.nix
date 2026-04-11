{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.shell-apps._.${moduleName}.homeManager = {
        # description = "per-character in-line diff";
        home.packages = with pkgs; [
            riffdiff
        ];
    };
}
