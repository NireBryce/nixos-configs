{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "bitwarden - password manager https://bitwarden.com/";
      home.packages = with pkgs; [
        bitwarden-desktop
      ];
    };
  };
}
