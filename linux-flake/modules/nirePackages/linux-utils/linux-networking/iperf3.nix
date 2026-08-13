{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }:
            lib.mkIf (!pkgs.stdenv.isDarwin) {
        # # description = "network tools https://software.es.net/iperf/";
            home.packages = with pkgs; [
                iperf3
            ];
        };
}
