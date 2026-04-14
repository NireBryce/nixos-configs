{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = 
        { pkgs, ... }: {    
        # # description = "tldr - community provided man pages";
            home.packages = with pkgs; [
                tldr
            ];
    };
}
