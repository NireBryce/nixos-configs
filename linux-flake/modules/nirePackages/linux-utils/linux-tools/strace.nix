{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: lib.mkIf (!pkgs.stdenv.isDarwin) {
            # # description = "system call tracer https://linux.die.net/man/1/strace";
            home.packages = with pkgs; [
                strace
            ];
        };
}
