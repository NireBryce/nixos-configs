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
      hardware.enableAllFirmware = true;
      hardware.enableRedistributableFirmware = true;
      nixpkgs.config.allowUnfree = true; # enableAllFirmware depends on this
    };
  };
}
