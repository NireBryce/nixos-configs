{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = { pkgs, ... }: {
        # # description = "`du` alternative";
        home.packages = with pkgs; [
            dust
        ];
    };
}
