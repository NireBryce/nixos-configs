{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.optional._.${moduleName}.homeManager = {
        # description = "qpw graph virtual mixer";
        home.packages = with pkgs; [
            qpwgraph
        ];
    };
}
