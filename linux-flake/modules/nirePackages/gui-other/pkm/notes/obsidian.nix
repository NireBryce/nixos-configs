{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
        # # description = "Obsidian - markdown PKM like org mode, https://obsidian.md/";
            home.packages = with pkgs; [
                obsidian
            ];
        };
}
