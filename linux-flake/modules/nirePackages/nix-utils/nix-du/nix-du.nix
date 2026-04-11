{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.packages._.${moduleName}.homeManager = {
        # description = "nix-store analysis"; 
        home.packages = with pkgs; [
            nix-du
        ];
    };
}
