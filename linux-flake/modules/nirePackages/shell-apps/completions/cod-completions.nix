{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  aspectChain = den.aspects.moduleStore._.${moduleName};
in
{
  ${aspectChain} = den.lib.perHost {
  nixos =
    { pkgs, ... }:
    {
      # # description = "Cod - Completion daemon";
      # I think it needs to be system installed to access system shells
      environment.systemPackages = with pkgs; [
        cod
      ];
    };
  };
}
