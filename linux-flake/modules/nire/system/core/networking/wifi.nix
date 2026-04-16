{ den, lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  aspectChain = den.aspects.moduleStore._.${moduleName};
  
in
{
  
  ${aspectChain} = den.lib.perHost {
  nixos =
    { ... }:
    {
      networking.networkmanager.enable = true; # Needs to be 'true' for KDE networking
    };
  };
}
