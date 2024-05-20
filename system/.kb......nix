{ lib, ... }:
{
  imports = [
    ./.kb.zsa+.nix
  ];
  _zsa.enable = lib.mkDefault true;
}
