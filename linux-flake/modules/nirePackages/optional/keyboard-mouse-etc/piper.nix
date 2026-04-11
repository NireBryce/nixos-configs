{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.optional._.${moduleName}.homeManager = {
        # description = "piper - logitech/razer graphical mouse manager https://github.com/soxoj/piper";
        home.packages = with pkgs; [
            piper
        ];
    };
}
