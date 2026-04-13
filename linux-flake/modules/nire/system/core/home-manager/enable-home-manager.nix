{ inputs, lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  # den.ctx.hm-host.includes = [ ];
  # den.ctx.hm-user.includes = [ ];

  nire.moduleStore._.${moduleName}.nixos =
    { ... }:
    {
      imports = [
        inputs.home-manager.nixosModules.home-manager
      ];

    };
}
