{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager =  { pkgs, ... }: {
        # # description = "ethtool https://www.kernel.org/pub/software/network/ethtool/";
        home.packages = with pkgs; [
            ethtool
        ];
    };
}
