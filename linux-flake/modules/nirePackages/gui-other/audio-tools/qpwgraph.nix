{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager = 
      { pkgs, ... }: 
      {
      # # description = "qpw graph virtual mixer";
      home.packages = with pkgs; [
        qpwgraph
      ];
    };
  };
}
