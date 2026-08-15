{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
                # # description = "opencode: AI coding agent built for the terminal"
                home.packages = with pkgs; [
                    opencode
                ];
        };
}
