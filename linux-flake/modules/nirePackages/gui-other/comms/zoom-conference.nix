{ pkgs, lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  nirePackages.packages._.${moduleName}.homeManager = {
    description = "zoom videoconferencing software";
    home.packages = with pkgs; [
      zoom-us
    ];
  };
}
