{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
                # # description = "herdr: agent multiplexer that lives in your terminal"
                home.packages = with pkgs; [
                    herdr
                ];
        };
}
