{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.packages._.${moduleName}.homeManager = {
        # description = "`bat` - syntax highlighted `cat` and `less` replacement https://github.com/sharkdp/bat;";
        home.packages = with pkgs; [
            bat
        ];
    };
}
