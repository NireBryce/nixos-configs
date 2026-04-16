{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "library call tracer https://linux.die.net/man/1/ltrace";
      home.packages = with pkgs; [
        ltrace
      ];
    };};
}
