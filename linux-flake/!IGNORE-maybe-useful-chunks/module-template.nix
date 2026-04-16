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

    };
  };
  ${aspectChain} = den.lib.perUser { 
    homeManager =
    { ... }:
    {

    };
  };

}
