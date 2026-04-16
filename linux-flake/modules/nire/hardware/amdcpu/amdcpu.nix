{ den, inputs, lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  aspectChain = den.aspects.moduleStore._.${moduleName};
in
{
  ${aspectChain} = den.lib.perHost { 
    nixos =
    { ... }:
    {
      imports = [
        inputs.nixos-hardware.nixosModules.common-cpu-amd
      ];
    };
  };
}
