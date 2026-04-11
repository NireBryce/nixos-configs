{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.shell-apps._.${moduleName}.homeManager = {
        # description = "vivid - LS_COLORS generator";
        home.packages = with pkgs; [
            vivid
        ];
    };
}
