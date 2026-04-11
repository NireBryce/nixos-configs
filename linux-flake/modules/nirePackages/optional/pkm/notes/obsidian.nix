{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.optional._.${moduleName}.homeManager = {
        # description = "Obsidian - markdown PKM like org mode, https://obsidian.md/";
        home.packages = with pkgs; [
            obsidian
        ];
    };
}
