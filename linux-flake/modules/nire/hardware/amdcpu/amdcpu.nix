{ inputs, lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  nire.moduleStore._.${moduleName}.nixos =
    { pkgs, ... }:
    {
      imports = [
        inputs.nixos-hardware.nixosModules.common-cpu-amd
      ];
    };
}
