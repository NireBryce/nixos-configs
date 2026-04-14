{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = { pkgs, ... }: {
        # # description = "`rg` is a much faster and more powerful grep alternative";
        home.packages = with pkgs; [
            ripgrep
        ];
    };
}
