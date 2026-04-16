{ den, lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perHost {
    nixos =
    { ... }:
    {
      time.timeZone = lib.mkDefault "America/New_York";
    };
  };
}
