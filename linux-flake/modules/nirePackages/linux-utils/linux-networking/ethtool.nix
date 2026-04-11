{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.packages._.${moduleName}.homeManager =  {
        # description = "ethtool https://www.kernel.org/pub/software/network/ethtool/";
        home.packages = with pkgs; [
            ethtool
        ];
    };
}
