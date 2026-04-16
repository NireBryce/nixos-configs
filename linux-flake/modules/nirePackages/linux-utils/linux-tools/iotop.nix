{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "iotop - io monitoring http://guichaz.free.fr/iotop";
      home.packages = with pkgs; [
        iotop
      ];
    };};
}
