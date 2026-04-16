{ lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  den.aspects.moduleStore._.${moduleName}.nixos =
    { ... }:
    {
      services.ratbagd.enable = true; # for piper logitech mouse ctl
    };
}
