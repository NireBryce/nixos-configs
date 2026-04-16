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
      # # description = "nix-ld, needed for VSCode remote connection, etc";
      programs.nix-ld.enable = lib.mkDefault true;
    };
  };
}
