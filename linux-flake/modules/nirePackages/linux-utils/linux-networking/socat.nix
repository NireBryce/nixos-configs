{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "openbsd netcat replacement https://www.dest-unreach.org/socat/";
      home.packages = with pkgs; [
        socat
      ];
    };
    };
}
