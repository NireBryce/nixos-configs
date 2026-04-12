{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = { pkgs, ... }: {
    # description = "`df` alternative";
        home.packages = with pkgs; [
            duf
        ];
    };
}
