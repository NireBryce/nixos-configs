{ den, lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perHost {
    nixos =
      { ... }:
      {
        nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      };
  };
}
