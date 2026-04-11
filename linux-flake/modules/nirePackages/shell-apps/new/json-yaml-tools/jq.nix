{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.shell-apps._.${moduleName}.homeManager = {
        # description = "jq https://github.com/stedolan/jq";
        home.packages = with pkgs; [
            jq
        ];
    };
}
