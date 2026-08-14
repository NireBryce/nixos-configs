{ lib, ... }:
  let
    moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  in {
        flake.modules.homeManager.${moduleName} = {
            home.stateVersion   = lib.mkDefault "22.11";
            home.username       = lib.mkDefault "elly";
            home.homeDirectory  = lib.mkDefault "/home/elly"; # Darwin is different
        };
}
