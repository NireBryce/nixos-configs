{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.linux-utils._.${moduleName}.homeManager =  {
        # description =  "mtr - traceroute + ping https://www.bitwizard.nl/mtr/";
        home.packages = with pkgs; [
            mtr
        ];
    };
}
