{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "ethtool https://www.kernel.org/pub/software/network/ethtool/";
      home.packages = with pkgs; [
        ethtool
      ];
    };
  };
}
