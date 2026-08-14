{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: { 
            # terminal markdown viewer https://github.com/charmbracelet/glow
            home.packages = with pkgs; [
                glow
            ];
        };
}
