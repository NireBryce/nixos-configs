{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager =  { pkgs, ... }: {
        # # description = "`lspci`";
        home.packages = with pkgs; [
            pciutils
        ];
    };
}
