{ lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  nire.moduleStore._.${moduleName}.homeManager =
    { pkgs, ... }:
    {
      # description = "gimp - the GNU Image Manipulation Program. https://www.gimp.org";
      home.packages = with pkgs; [
        gimp
      ];
    };
}
