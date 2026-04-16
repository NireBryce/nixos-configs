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
      services.ratbagd.enable = true; # for piper logitech mouse ctl
    };
  };
}
