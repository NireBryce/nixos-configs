{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }:
            lib.mkIf (!pkgs.stdenv.isDarwin) {
            # # description = "`lspci`";
            home.packages = with pkgs; [
                pciutils
            ];
        };
}
