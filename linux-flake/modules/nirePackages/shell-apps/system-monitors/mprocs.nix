{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = { pkgs, ... }: {
        # description = "run multiple commands in parallel";
        home.packages = with pkgs; [
            mprocs
        ];
    };
}
