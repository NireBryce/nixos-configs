{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = { pkgs, ... }: {
        # description = "nix-store analysis"; 
        home.packages = with pkgs; [
            nix-du
        ];
    };
}
