{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
        # home-manager instance of python3
            home.packages = with pkgs; [
                python3
            ];
        };
}
