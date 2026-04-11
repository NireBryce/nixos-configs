{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.packages._.${moduleName}.homeManager = {
        # description = "`find` alternative";
        home.packages = with pkgs; [
            fd
        ];
    };
}
