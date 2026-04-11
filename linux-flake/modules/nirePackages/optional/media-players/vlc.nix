{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.optional._.${moduleName}.homeManager = {
        # description = "vlc media player";
        home.packages = with pkgs; [
            vlc
        ];
    };
}
