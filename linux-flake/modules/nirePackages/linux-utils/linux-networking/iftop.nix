{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.packages._.${moduleName}.homeManager =  {
        # description = "network monitor https://pdw.ex-parrot.com/iftop/";
        home.packages = with pkgs; [
            iftop
        ];
    };
}
