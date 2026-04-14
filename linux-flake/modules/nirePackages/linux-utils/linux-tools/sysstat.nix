{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = { pkgs, ... }: {
        # # description = "system stats http://sebastien.godard.pagesperso-orange.fr/";
        home.packages = with pkgs; [
            sysstat
        ];
    };
}
