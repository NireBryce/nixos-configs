{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.shell-apps._.${moduleName}.homeManager = {
    # description = "`df` alternative";
        home.packages = with pkgs; [
            duf
        ];
    };
}
