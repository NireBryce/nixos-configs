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
      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
  };
}
