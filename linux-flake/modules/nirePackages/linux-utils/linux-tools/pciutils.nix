{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nirePackages.linux-utils._.${moduleName}.homeManager =  {
        # description = "`lspci`";
        home.packages = with pkgs; [
            pciutils
        ];
    };
}
