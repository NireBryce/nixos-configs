{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # bitwarden - password manager https://bitwarden.com/
            home.packages = with pkgs; [
                bitwarden-desktop
            ];
        };
}
