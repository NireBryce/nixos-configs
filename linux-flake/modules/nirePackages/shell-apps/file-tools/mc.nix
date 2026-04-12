{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = {
        # description = "midnight commander file browser";
        home.packages = with pkgs; [
            mc
        ];
    };
}
