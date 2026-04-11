{ pkgs, lib, ... }:
let
  moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
in
{
  nirePackages.packages._.${moduleName}.homeManager = {
    # nushell - the next generation shell
    # hint: nushell -c for tabular display in any shell
    home.packages = with pkgs; [
      nushell
    ];
  };
}
