{ pkgs, lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  nirePackages.packages._.${moduleName}.homeManager = {
    # description ="kanata - input-level keybinding, platform independent";
    home.packages = with pkgs; [
      kanata
    ];
  };
}
