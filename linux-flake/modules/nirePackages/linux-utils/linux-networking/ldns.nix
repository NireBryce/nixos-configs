{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "provides `drill`, a `dig` replacement https://www.nlnetlabs.nl/projects/ldns/about/";
      home.packages = with pkgs; [
        ldns
      ];
    };
  };
}
