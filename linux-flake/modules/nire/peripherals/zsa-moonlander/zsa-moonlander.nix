{ lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  nire.moduleStore._.${moduleName}.nixos =
    { pkgs, ... }:
    {
      hardware.keyboard.zsa.enable = true; # zsa keyboard package
    };
}
