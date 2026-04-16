{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "system call tracer https://linux.die.net/man/1/strace";
      home.packages = with pkgs; [
        strace
      ];
    };};
}
