{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # neovim - it's like vim but heavier
            home.packages = with pkgs; [ neovim ];
        };
}
