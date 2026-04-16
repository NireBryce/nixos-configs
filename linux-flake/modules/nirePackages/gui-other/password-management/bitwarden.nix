{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  aspectChain = den.aspects.moduleStore._.${moduleName};
in
{
  nire.moduleStore._.${moduleName}.homeManager =
    { pkgs, ... }:
    {
      # # description = "bitwarden - password manager https://bitwarden.com/";
      home.packages = with pkgs; [
        bitwarden-desktop
      ];
    };
}
