{ pkgs, lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  nire.moduleStore._.${moduleName}.homeManager = {
    # description = "discord gamer chat app that broke containment";
    home.packages = with pkgs; [
      discord
    ];
  };
}
