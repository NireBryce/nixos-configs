{ lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  nire.moduleStore._.${moduleName}.homeManager =
    { pkgs, ... }:
    {
      # description ="kanata - input-level keybinding, platform independent";
      home.packages = with pkgs; [
        kanata
      ];
    };
}
