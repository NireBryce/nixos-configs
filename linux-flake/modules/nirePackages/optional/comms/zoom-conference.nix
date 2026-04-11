{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.optional._.${moduleName}.homeManager = {
        description = "zoom videoconferencing software";
        home.packages = with pkgs; [
            zoom-us
        ];
    };
}
