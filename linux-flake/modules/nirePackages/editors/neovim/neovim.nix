{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.packages._.${moduleName}.homeManager = {
        # neovim - it's like vim but heavier
        home.packages = with pkgs; [
            neovim
        ];
    };
}
