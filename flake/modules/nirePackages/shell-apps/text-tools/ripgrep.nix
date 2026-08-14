{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.homeManager.${moduleName} = { pkgs, ... }: { 
            # `rg` is a much faster and more powerful grep alternative
            home.packages = with pkgs; [
                ripgrep
            ];
        };
}
