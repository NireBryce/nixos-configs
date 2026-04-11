{ pkgs, lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  nirePackages.packages._.${moduleName}.homeManager = {
    # description = "discord gamer chat app that broke containment";
    home.packages = with pkgs; [
      discord
    ];
  };
}
