{ lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  nire.moduleStore._.${moduleName}.homeManager =
    { pkgs, ... }:
    {
      # home-manager instance of python3
      home.packages = with pkgs; [
        python3
      ];
    };
}
