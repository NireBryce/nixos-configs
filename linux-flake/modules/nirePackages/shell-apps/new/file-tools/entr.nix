{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.shell-apps._.${moduleName}.homeManager = {
        # description = "run commands when file changes";
        home.packages = with pkgs; [
            entr
        ];
    };
}
