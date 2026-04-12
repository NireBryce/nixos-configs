{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = {
        # description = "an application to show file info";
        home.packages = with pkgs; [
            file
        ];
    };
}
