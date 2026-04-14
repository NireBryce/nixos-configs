{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager =  {
        # # description = "iotop - io monitoring http://guichaz.free.fr/iotop";
        home.packages = with pkgs; [
            iotop
        ];
    };
}
