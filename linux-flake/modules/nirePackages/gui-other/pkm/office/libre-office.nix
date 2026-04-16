{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  aspectChain = den.aspects.moduleStore._.${moduleName};
in
{
  nire.moduleStore._.${moduleName}.homeManager =
    { pkgs, ... }:
    {
      # # description = "libreoffice - office productivity software https://www.libreoffice.org/";
      home.packages = with pkgs; [
        libreoffice-qt
      ];
    };
}
