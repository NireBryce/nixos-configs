{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.packages._.${moduleName}.homeManager = {
        # description = "view nix dependency graph";
        home.packages = with pkgs; [
            nix-tree
        ];
    };
}
