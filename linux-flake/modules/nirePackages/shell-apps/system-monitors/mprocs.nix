{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.packages._.${moduleName}.homeManager = {
        # description = "run multiple commands in parallel";
        home.packages = with pkgs; [
            mprocs
        ];
    };
}
