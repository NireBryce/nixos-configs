{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = {
        # description = "neofetch replacement https://github.com/hykilpikonna/HyFetch";
        home.packages = with pkgs; [
            hyfetch
        ];
    };
}
