{ lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  nirePackages.packages._.${moduleName}.homeManager = {
    # description = "promnesia breadcrumb-bookmarks-and-more";
    home.file.".config/promnesia".source = ./config/config.py;
  };
}
