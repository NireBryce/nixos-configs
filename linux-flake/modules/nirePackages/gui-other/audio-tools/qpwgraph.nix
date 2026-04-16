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
      # # description = "qpw graph virtual mixer";
      home.packages = with pkgs; [
        qpwgraph
      ];
    };
  };
}
