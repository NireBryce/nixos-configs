{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # IP address calculator https://gitlab.com/ipcalc/ipcalc
            home.packages = with pkgs; [
                ipcalc
            ];
        };
}
