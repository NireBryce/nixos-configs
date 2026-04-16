{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "neofetch replacement https://github.com/hykilpikonna/HyFetch";
      home.packages = with pkgs; [
        hyfetch
      ];
    };
  };
}
