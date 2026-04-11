{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.packages._.${moduleName}.homeManager =  {
        # description = "provides `drill`, a `dig` replacement https://www.nlnetlabs.nl/projects/ldns/about/";
        home.packages = with pkgs; [
            ldns
        ];
    };
}
