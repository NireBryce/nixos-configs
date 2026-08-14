{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # iotop - io monitoring http://guichaz.free.fr/iotop
            home.packages = with pkgs; [
                iotop
            ];
        };
}
