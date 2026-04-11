{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.development._.${moduleName}.homeManager = {
        home.packages = with pkgs; [
            claude-code
        ];
    };
}

