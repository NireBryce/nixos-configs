{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "libreoffice - office productivity software https://www.libreoffice.org/";
      home.packages = with pkgs; [
        libreoffice-qt
      ];
    };
  };
}
