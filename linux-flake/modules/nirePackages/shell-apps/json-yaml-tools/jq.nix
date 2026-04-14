{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = { pkgs, ... }: {
        # # description = "jq https://github.com/stedolan/jq";
        home.packages = with pkgs; [
            jq
        ];
    };
}
