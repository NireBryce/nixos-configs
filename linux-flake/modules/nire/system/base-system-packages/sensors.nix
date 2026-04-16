{ lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  den.aspects.moduleStore._.${moduleName}.nixos =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        lm_sensors # lm_sensors
      ];
    };
}
