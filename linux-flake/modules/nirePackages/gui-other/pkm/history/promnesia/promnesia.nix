{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  aspectChain = den.aspects.moduleStore._.${moduleName};
in
{
  nire.moduleStore._.${moduleName}.homeManager =
    { ... }:
    {
      # # description = "promnesia breadcrumb-bookmarks-and-more";
      home.file.".config/promnesia".source = ./config/config.py;
    };
}
