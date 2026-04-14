{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager =  {
        # # description = "IP address calculator https://gitlab.com/ipcalc/ipcalc";
        home.packages = with pkgs; [
            ipcalc
        ];
    };
}
