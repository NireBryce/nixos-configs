{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
 
  den.aspects.moduleStore._.${moduleName} = den.lib.perUser {
    homeManager =
    { pkgs, ... }:
    {
      # # description = "wh - magic-wormhole point to point file transfer";
      home.packages = with pkgs; [
        magic-wormhole-rs
      ];
    };};
}
