{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.packages._.${moduleName}.homeManager = {
        # description = "diff nix code";
        home.packages = with pkgs; [
            nix-diff
        ];
    };
}
