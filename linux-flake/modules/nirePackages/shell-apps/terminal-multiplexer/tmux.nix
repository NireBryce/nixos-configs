{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { ... }:
    {
      # # description = "tmux - terminal multiplexer";
      programs.tmux = {
        enable = true;
      };
    };
  };
}
