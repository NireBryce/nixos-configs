{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # description = "better pager for some things https://github.com/walles/moor";
      home.packages = with pkgs; [
        moor # moar renamed to moor https://github.com/walles/moor/pull/305
      ];
    };
  };
}
