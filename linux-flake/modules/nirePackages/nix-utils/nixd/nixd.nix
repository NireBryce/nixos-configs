{ pkgs, lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = {
        # description = "nixd lsp";
        home.packages = with pkgs; [
            nixd
        ];
    };
}
