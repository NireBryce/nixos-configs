{ pkgs, lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  nirePackages.packages._.${moduleName}.homeManager = {
    # home-manager instance of python3
    home.packages = with pkgs; [
      python3
    ];
  };
}
