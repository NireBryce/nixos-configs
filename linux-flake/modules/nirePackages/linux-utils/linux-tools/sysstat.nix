{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "system stats http://sebastien.godard.pagesperso-orange.fr/";
      home.packages = with pkgs; [
        sysstat
      ];
    };};
}
