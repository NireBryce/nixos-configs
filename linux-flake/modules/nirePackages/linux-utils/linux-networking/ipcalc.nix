{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  aspectChain = den.aspects.moduleStore._.${moduleName};
in
{
  ${aspectChain} = den.lib.perUser {
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
