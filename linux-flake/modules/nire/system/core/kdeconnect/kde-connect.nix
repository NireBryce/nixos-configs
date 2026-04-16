{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  den.aspects.moduleStore._.${moduleName} = den.lib.perHost {
    nixos = 
    { ... }:
    {
      # todo: shouldn't this be a service?
      programs.kdeconnect = {
        enable = true; # kde connect
      };
    };
  };
}
