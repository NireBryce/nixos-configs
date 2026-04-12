{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = { pkgs, ... }: {
        # description = "vivid - LS_COLORS generator";
        home.packages = with pkgs; [
            vivid
        ];
    };
}
