{ lib, ...}:
{
  imports = [
    ./.ipr.delete-root+.nix
    ./.ipr.impermanence+.nix
    ./.ipr.system-partitions+.nix
   ];
   _delete-root.enable = lib.mkDefault true;
   _system-partitions.enable = lib.mkDefault true;
   _impermanence.enable = lib.mkDefault true;
}
