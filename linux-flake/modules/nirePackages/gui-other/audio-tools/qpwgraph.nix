{ lib, ... }:
    let
      moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # PipeWire is Linux-only; meta.platforms excludes aarch64-darwin.
            # # description = "qpw graph virtual mixer";
            home.packages = with pkgs; [
                qpwgraph
            ];
        };
}
