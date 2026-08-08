{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # # description = "nixfmt - .nix file formatter";
            home.packages = with pkgs; [
                nixfmt
            ];
        };
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
            environment.systemPackages = with pkgs; [
                nixfmt
            ];
        };
}
