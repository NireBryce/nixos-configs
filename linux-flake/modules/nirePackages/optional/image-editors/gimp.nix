{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.optional._.${moduleName}.homeManager = {
        # description = "gimp - the GNU Image Manipulation Program. https://www.gimp.org";
        home.packages = with pkgs; [
            gimp
        ];
    };
}
