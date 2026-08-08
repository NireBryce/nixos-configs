{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
            # # description = "bitwarden - password manager https://bitwarden.com/";
            home.packages = with pkgs; [
                bitwarden-desktop
            ];
        };
}
