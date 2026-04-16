{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  aspectChain = den.aspects.moduleStore._.${moduleName};
in
{
  nire.moduleStore._.${moduleName}.homeManager =
    { pkgs, ... }:
    {
      # # description = "Obsidian - markdown PKM like org mode, https://obsidian.md/";
      home.packages = with pkgs; [
        obsidian
      ];
    };
}
