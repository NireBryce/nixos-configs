{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = {
        # description = "yaml jq https://github.com/mikefarah/yq";
        home.packages = with pkgs; [
            yq-go
        ];
    };
}
