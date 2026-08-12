{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: lib.mkIf (!pkgs.stdenv.isDarwin) {
            # # description = "openbsd netcat replacement https://www.dest-unreach.org/socat/";
            home.packages = with pkgs; [
                socat
            ];
        };
}
