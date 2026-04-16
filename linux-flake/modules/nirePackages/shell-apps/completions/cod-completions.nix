{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perHost {
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
