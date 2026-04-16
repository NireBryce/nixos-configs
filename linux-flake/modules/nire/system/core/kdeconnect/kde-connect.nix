{ lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
${aspectChain} = den.lib.perHost {
    nixos = { config, ... }: { =
    { ... }:
    {
      # todo: shouldn't this be a service?
      programs.kdeconnect = {
        enable = true; # kde connect
      };
    };
}
