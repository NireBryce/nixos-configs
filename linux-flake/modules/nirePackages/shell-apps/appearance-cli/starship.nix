{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  aspectChain = den.aspects.moduleStore._.${moduleName};
in
{
  nire.moduleStore._.${moduleName}.homeManager =
    { ... }:
    {
      programs.starship = {
        enable = true;
        enableBashIntegration = true;
        enableZshIntegration = true;
        enableFishIntegration = true;
      };
    };
}
