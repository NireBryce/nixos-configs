{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.shell-apps._.${moduleName}.homeManager = {
    # description = "aria2 -cli download manager";
        home.packages = with pkgs; [
            aria2
        ];
    };
}
