{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "jc converts output into JSON or YAML https://github.com/kellyjonbrazil/jc";
      home.packages = with pkgs; [
        jc
      ];
    };};
}
