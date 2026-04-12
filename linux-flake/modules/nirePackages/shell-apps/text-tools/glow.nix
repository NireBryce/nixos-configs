{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = { pkgs, ... }: {
        # description = "terminal markdown viewer https://github.com/charmbracelet/glow";
        home.packages = with pkgs; [
            glow
        ];
    };
}
