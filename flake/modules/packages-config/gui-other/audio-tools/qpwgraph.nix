{ lib, ... }:
    let
      moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # virtual mixer
            home.packages = with pkgs; [
                qpwgraph
            ];
        };
}
