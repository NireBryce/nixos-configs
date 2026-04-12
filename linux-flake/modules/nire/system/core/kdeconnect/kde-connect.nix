{ lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  nire.moduleStore._.${moduleName}.nixos =
    { ... }:
    {
      # todo: shouldn't this be a service?
      programs.kdeconnect = {
        enable = true; # kde connect
      };
    };
}
