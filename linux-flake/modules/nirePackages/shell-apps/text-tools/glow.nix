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
      # # description = "terminal markdown viewer https://github.com/charmbracelet/glow";
      home.packages = with pkgs; [
        glow
      ];
    };
  };
}
