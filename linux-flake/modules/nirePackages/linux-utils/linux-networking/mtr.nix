{  lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager =  { pkgs, ... }: {
        # description =  "mtr - traceroute + ping https://www.bitwizard.nl/mtr/";
        home.packages = with pkgs; [
            mtr
        ];
    };
}
