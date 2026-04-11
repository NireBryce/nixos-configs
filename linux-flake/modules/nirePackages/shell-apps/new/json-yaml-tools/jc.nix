{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.shell-apps._.${moduleName}.homeManager = {
        # description = "jc converts output into JSON or YAML https://github.com/kellyjonbrazil/jc";
        home.packages = with pkgs; [
            jc
        ];
    };
}
