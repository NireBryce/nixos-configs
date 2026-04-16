{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "IP address calculator https://gitlab.com/ipcalc/ipcalc";
      home.packages = with pkgs; [
        ipcalc
      ];
    };
  };
}
