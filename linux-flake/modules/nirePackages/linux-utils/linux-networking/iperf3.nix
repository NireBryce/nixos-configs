{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager =  {
        # # description = "network tools https://software.es.net/iperf/";
        home.packages = with pkgs; [
            iperf3
        ];
    };
}
