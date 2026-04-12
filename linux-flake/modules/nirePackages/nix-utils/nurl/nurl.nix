{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = {
        # description = "make nix fetcher calls from repository URLs";
        home.packages = with pkgs; [
            nurl
        ];
    };
}
