{ lib, ... }:
    let
      moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, lib, ... }:
            # PipeWire is Linux-only; nixpkgs doesn't build qpwgraph for
            # aarch64-darwin.
            lib.mkIf (!pkgs.stdenv.isDarwin) {
            # # description = "qpw graph virtual mixer";
            home.packages = with pkgs; [
                qpwgraph
            ];
        };
}
