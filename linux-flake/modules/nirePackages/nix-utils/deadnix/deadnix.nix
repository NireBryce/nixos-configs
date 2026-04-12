{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = {
        #  description = "scan for 'dead' (uncalled) nix code";
        home.packages = with pkgs; [
            deadnix
        ];
    };
}
