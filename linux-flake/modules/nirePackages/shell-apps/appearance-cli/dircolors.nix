{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  aspectChain = den.aspects.moduleStore._.${moduleName};
in
{
  nire.moduleStore._.${moduleName}.homeManager =
    { ... }:
    {
      programs.dircolors = {
        enable = true;
        enableZshIntegration = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
      };
    };
}
