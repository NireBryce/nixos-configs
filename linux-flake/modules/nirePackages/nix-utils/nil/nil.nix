{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.packages._.${moduleName}.homeManager = {
        # description = "nil - a nix LSP server";
        home.packages = with pkgs; [
            nil
        ];
    };
}
