{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # description ="kanata - input-level keybinding, platform independent";
      home.packages = with pkgs; [
        kanata
      ];
    };
  };
}
