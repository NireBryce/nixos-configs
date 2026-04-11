{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.packages._.${moduleName}.homeManager = {
        #  description = "scan for 'dead' (uncalled) nix code";
        home.packages = with pkgs; [
            deadnix
        ];
    };
}
