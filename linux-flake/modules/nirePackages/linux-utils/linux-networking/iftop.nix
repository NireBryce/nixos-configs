{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "network monitor https://pdw.ex-parrot.com/iftop/";
      home.packages = with pkgs; [
        iftop
      ];
    };
  };
}
