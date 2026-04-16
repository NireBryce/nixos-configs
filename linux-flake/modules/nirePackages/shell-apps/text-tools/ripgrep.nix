{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "`rg` is a much faster and more powerful grep alternative";
      home.packages = with pkgs; [
        ripgrep
      ];
    };
  };
}
