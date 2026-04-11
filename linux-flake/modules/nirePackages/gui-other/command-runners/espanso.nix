{ lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  nirePackages.packages._.${moduleName}.homeManager = {
    # description = "espanso is a text expansion tool that turns a trigger phrase into text";
    services.espanso = {
      enable = true;
      waylandSupport = true;
    };
  };
}
