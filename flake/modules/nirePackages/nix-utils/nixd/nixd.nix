{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: {
            # nixd lsp
            home.packages = with pkgs; [
                nixd
            ];
        };
  
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
            environment.systemPackages = with pkgs; [
                nixd
            ];
        };
}

