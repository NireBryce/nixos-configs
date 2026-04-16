{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "list open files https://linux.die.net/man/1/lsof";
      home.packages = with pkgs; [
        lsof
      ];
    };};
}
