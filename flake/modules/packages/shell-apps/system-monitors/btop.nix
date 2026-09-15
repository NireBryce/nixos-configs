{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: { 
            # `htop` alternative
            home.packages = with pkgs; [
                btop
            ];
        };
}
