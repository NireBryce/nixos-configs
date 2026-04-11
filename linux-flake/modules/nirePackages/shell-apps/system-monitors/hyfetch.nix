{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.packages._.${moduleName}.homeManager = {
        # description = "neofetch replacement https://github.com/hykilpikonna/HyFetch";
        home.packages = with pkgs; [
            hyfetch
        ];
    };
}
