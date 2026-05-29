{ lib, pkgs, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
    flake.modules.home-manager.${moduleName} = {
        home.packages = with pkgs; [
            ruff
        ];
    };
    
}
