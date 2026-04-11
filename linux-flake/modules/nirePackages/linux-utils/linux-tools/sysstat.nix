{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.linux-utils._.${moduleName}.homeManager = {
        # description = "system stats http://sebastien.godard.pagesperso-orange.fr/";
        home.packages = with pkgs; [
            sysstat
        ];
    };
}
