{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # description = "zoom videoconferencing software";
      home.packages = with pkgs; [
        zoom-us
      ];
    };
  };
}
