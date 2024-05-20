{ lib, ... }:
{
  imports = [
    ./.usr.elly.nix
   ];
  _usr-elly.enable = lib.mkDefault true;
}
