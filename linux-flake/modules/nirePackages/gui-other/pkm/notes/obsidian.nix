{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "Obsidian - markdown PKM like org mode, https://obsidian.md/";
      home.packages = with pkgs; [
        obsidian
      ];
    };
  };
}
