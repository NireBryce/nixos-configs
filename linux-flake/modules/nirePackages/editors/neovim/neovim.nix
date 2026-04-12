{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = { pkgs, ... }: {
        # neovim - it's like vim but heavier
        home.packages = with pkgs; [
            neovim
        ];
    };
}
