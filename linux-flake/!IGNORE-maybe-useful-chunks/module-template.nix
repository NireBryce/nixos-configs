{ lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  nire.moduleStore._.${moduleName} = {
    homeManager =
      { ... }:
      {

      };

    nixos =
      { ... }:
      {

      };

    darwin = {

    };
  };
}
