{ lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  nire.moduleStore._.${moduleName}.nixos =
    { ... }:
    {
      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
}
