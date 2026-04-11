{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.shell-apps._.${moduleName}.homeManager = {
        # description = "run multiple commands in parallel";
        home.packages = with pkgs; [
            mprocs
        ];
    };
}
