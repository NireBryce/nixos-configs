{ inputs, lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  nire.moduleStore._.${moduleName}.nixos =
    { ... }:
    {
      imports = [
        inputs.home-manager.nixosModules.home-manager
      ];
    };
}
