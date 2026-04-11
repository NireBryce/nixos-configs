{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.packages._.${moduleName}.homeManager = {
        # description = "wh - magic-wormhole point to point file transfer";
        home.packages = with pkgs; [
            magic-wormhole-rs
        ];
    };
}
