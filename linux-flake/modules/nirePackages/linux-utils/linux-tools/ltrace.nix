{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: lib.mkIf (!pkgs.stdenv.isDarwin) {
            # # description = "library call tracer https://linux.die.net/man/1/ltrace";
            home.packages = with pkgs; [
                ltrace
            ];
        };
}
