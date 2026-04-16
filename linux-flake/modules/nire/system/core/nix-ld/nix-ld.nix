{ lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  den.aspects.moduleStore._.${moduleName}.nixos =
    { ... }:
    {
      # # description = "nix-ld, needed for VSCode remote connection, etc";
      programs.nix-ld.enable = lib.mkDefault true;
    };
}
