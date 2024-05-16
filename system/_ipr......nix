{ lib, ...}:
{
  imports = [
    ./_ipr.delete-root+.nix
    ./_ipr.impermanence+.nix
    ./_ipr.system-partitions+.nix
   ];
   _delete-root.enable = lib.mkDefault true;
   _system-partitions.enable = lib.mkDefault true;
   _impermanence.enable = lib.mkDefault true;
}
