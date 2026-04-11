{ pkgs, lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  nirePackages.packages._.${moduleName}.homeManager = {
    # description = "libreoffice - office productivity software https://www.libreoffice.org/";
    home.packages = with pkgs; [
      libreoffice-qt
    ];
  };
}
