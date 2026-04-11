{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.shell-apps._.${moduleName}.homeManager = {    # description = "tldr - community provided man pages";
        home.packages = with pkgs; [
            tldr
        ];
    };
}
