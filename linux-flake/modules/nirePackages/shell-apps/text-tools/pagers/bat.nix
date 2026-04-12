{ lib, ... }:
let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in {
    nire.moduleStore._.${moduleName}.homeManager = { pkgs, ... }: {
        # description = "`bat` - syntax highlighted `cat` and `less` replacement https://github.com/sharkdp/bat;";
        home.packages = with pkgs; [
            bat
        ];
    };
}
