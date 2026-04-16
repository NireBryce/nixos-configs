{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  aspectChain = den.aspects.moduleStore._.${moduleName};
in
{
  nire.moduleStore._.${moduleName}.homeManager =
    { pkgs, ... }:
    {
      #  # description = "scan for 'dead' (uncalled) nix code";
      home.packages = with pkgs; [
        deadnix
      ];
    };
}
