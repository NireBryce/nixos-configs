{ den, lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perhost {
    nixos =
    { ... }:
    {
      services.fwupd.enable = lib.mkDefault true; # fwupd
    };
  };
}
