{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager =  {
        # # description = "network scanner http://www.nmap.org/";
        home.packages = with pkgs; [
            nmap
        ];
    };
}
