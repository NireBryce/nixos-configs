{ inputs, lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  den.aspects.moduleStore._.${moduleName}.nixos =
    { ... }:
    {
      imports = [
        inputs.nixos-hardware.nixosModules.common-cpu-amd
      ];
    };
}
