{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.packages._.${moduleName}.homeManager =  {
        # description = "network scanner http://www.nmap.org/";
        home.packages = with pkgs; [
            nmap
        ];
    };
}
