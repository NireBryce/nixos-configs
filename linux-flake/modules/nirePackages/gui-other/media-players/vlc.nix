{ lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  nire.moduleStore._.${moduleName}.homeManager = { pkgs, ... }: {
    # description = "vlc media player";
    home.packages = with pkgs; [
      vlc
    ];
  };
}
