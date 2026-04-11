{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.shell-apps._.${moduleName}.homeManager = {
        # description = "`rg` is a much faster and more powerful grep alternative";
        home.packages = with pkgs; [
            ripgrep
        ];
    };
}
