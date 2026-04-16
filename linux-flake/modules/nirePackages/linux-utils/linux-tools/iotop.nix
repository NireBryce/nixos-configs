{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  aspectChain = den.aspects.moduleStore._.${moduleName};
in
{
  nire.moduleStore._.${moduleName}.homeManager =
    { pkgs, ... }:
    {
      # # description = "iotop - io monitoring http://guichaz.free.fr/iotop";
      home.packages = with pkgs; [
        iotop
      ];
    };
}
