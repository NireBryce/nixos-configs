{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.packages._.${moduleName}.homeManager = {
        # description = "nix package version diff";
        home.packages = with pkgs; [
            nvd
        ];
    };
}
