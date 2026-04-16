{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { ... }:
    {
      # # description = "promnesia breadcrumb-bookmarks-and-more";
      home.file.".config/promnesia".source = ./config/config.py;
    };
  };
}
