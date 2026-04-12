{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = { pkgs, ... }: {
        # description = "nil - a nix LSP server";
        home.packages = with pkgs; [
            nil
        ];
    };
}
