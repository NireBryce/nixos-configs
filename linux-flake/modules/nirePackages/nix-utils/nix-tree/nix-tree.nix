{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.nix-utils._.${moduleName}.homeManager = {
        # description = "view nix dependency graph";
        home.packages = with pkgs; [
            nix-tree
        ];
    };
}
