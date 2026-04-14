{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = { pkgs, ... }: {
        # # description = "midnight commander file browser";
        home.packages = with pkgs; [
            mc
        ];
    };
}
