{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "rsync - back in my day we transfered our files uphill both ways";
      home.packages = with pkgs; [
        rsync
      ];
    };};
}
