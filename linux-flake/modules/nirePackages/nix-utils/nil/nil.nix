{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
  flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
        # # description = "nil - a nix LSP server";
            home.packages = with pkgs; [
                nil
            ];
        };
}
