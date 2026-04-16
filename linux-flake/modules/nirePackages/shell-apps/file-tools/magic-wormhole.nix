{ lib, den, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
  aspectChain = den.aspects.moduleStore._.${moduleName};
in
{
  nire.moduleStore._.${moduleName}.homeManager =
    { pkgs, ... }:
    {
      # # description = "wh - magic-wormhole point to point file transfer";
      home.packages = with pkgs; [
        magic-wormhole-rs
      ];
    };
}
