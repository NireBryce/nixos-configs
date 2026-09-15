{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # tldr - community provided man pages
            home.packages = with pkgs; [
                tldr
            ];
        };
}
