{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: { 
            # `bat` - syntax highlighted `cat` and `less` replacement https://github.com/sharkdp/bat
            home.packages = with pkgs; [
                bat
            ];
        };
}
