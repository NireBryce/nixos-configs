{ lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  den.aspects.moduleStore._.${moduleName}.nixos =
    { ... }:
    {
      networking.networkmanager.enable = true; # Needs to be 'true' for KDE networking
    };
}
