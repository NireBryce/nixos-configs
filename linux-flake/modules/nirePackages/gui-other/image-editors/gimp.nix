{ 
    perSystem = {pkgs, lib, ...}:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "gimp - the GNU Image Manipulation Program. https://www.gimp.org";
      home.packages = with pkgs; [
        gimp
      ];
    };
  };
}
