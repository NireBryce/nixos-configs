{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.nix-utils._.${moduleName}.homeManager = {
        # description = "nix package version diff";
        home.packages = with pkgs; [
            nvd
        ];
    };
}
