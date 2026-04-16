{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # description =  "mtr - traceroute + ping https://www.bitwizard.nl/mtr/";
      home.packages = with pkgs; [
        mtr
      ];
    };
  };
}
