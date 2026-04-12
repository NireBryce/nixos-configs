{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager =  {
        # description = "openbsd netcat replacement https://www.dest-unreach.org/socat/";
        home.packages  = with pkgs; [
            socat
        ];
    };
}
