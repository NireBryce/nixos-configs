{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.optional._.${moduleName}.homeManager = {
        # description = "bitwarden - password manager https://bitwarden.com/";
        home.packages = with pkgs; [
            bitwarden-desktop
        ];
    };
}
