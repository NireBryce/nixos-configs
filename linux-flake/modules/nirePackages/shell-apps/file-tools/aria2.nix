{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = { pkgs, ... }: {
    # description = "aria2 -cli download manager";
        home.packages = with pkgs; [
            aria2
        ];
    };
}
