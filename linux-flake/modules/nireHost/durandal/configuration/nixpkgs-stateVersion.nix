{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perHost {
    nixos =
      { ... }:
      {
        system.stateVersion = lib.mkDefault "23.11"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
      };
  };
}
