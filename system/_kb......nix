{ lib, ... }:
{
  imports = [
    ./_kb.zsa+.nix
  ];
  _zsa.enable = lib.mkDefault true;
}
